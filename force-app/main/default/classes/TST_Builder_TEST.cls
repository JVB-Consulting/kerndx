// SPDX-License-Identifier: BUSL-1.1
/**
 * Original sourced from https://github.com/benahm
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @description Test class for related factory
 *
 * @see TST_Builder
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.AvoidBooleanMethodParameters')
private class TST_Builder_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'TST_Builder_TEST-admin';
	private static final Integer SMALL_NUMBER_OF_RECORDS = 3;
	private static final String TEST_EMAIL = UTIL_Random.randomEmail();
	private static final String TEST_STRING = 'test';

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction.
	 */
	@TestSetup
	private static void setupTestAdmin()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Tests building a single SObject (Foobar__c) in memory (doInsert=true).
	 */
	@IsTest
	private static void buildSingleSObjectWithInsert()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			SObject sObjectInstance = TST_Builder.of(Foobar__c.SObjectType).build();

			Test.stopTest();

			Assert.isNotNull(sObjectInstance?.Id, 'The built SObject Id should not be null.');
		}
	}

	/**
	 * @description Tests building a single SObject (Foobar__c) in memory (doInsert=false).
	 */
	@IsTest
	private static void buildSingleSObjectWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			Foobar__c foobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.withRecordType(SEL_Foobar.RT_DEFAULT)
					.build();

			Test.stopTest();

			Assert.isNull(foobar.Id, 'The built SObject Id should be null.');
			Assert.isNotNull(foobar.RecordTypeId, 'The built SObject RecordTypeId should not be null.');
		}
	}

	/**
	 * @description Tests building a single SObject (Foobar__c) in memory (doInsert=false).
	 */
	@IsTest
	private static void buildSingleSObjectInvalidRecordType()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Builder.of(Foobar__c.SObjectType)
						.withoutInsertion()
						.withRecordType(UTIL_Random.randomName())
						.build();

				Test.stopTest();

				Assert.fail('Expected an Exception for a invalid Record Type Name but none was thrown.');

			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Invalid exception for an invalid Record Type Name.');
			}

		}
	}

	/**
	 * @description Tests building a multiple SObjects (Foobar__c) in memory (doInsert=true).
	 */
	@IsTest
	private static void buildMultipleSObjectsWithInsert()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			List<SObject> insertedObjects = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, insertedObjects.size(), 'Incorrect number of objects');
		}
	}

	/**
	 * @description Tests building a multiple SObjects (Foobar__c) in memory (doInsert=false).
	 */
	@IsTest
	private static void buildMultipleSObjectsWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			List<SObject> insertedObjects = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.withoutInsertion()
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, insertedObjects.size(), 'Incorrect number of objects');
		}
	}

	/**
	 * @description Tests building and inserting a Foobar__c (doInsert=true) with complex, multi-level self-lookup relationships,
	 * field overrides, and the DEFAULT_VALUE provider.
	 */
	@IsTest
	private static void buildAndInsertWithComplexRelationshipsAndDefaultValueProvider()
	{
		System.runAs(getTestAdmin())
		{
			// Use constants from SEL_Foobar
			String fieldName = SEL_Foobar.FIELD_NAME;
			String level1Name = SEL_Foobar.FIELD_PARENT_NAME;
			String level2Name = SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + level1Name;
			String level3Name = SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + level2Name;
			String level4Name = SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + level3Name;

			Map<String, Object> mapOfValuesOverride = new Map<String, Object>
			{
					SEL_Foobar.FIELD_TEXT => TEST_STRING, // Field on main record
					level1Name => TEST_STRING, // Level 1
					level2Name => TEST_STRING, // Level 2
					level3Name => TEST_STRING, // Level 3
					// Level 4, using auto-default
					level4Name => TST_Builder.autoDefaultFieldValueProvider
			};

			Test.startTest();
			SObject sObjectInstance = TST_Builder.of(Foobar__c.SObjectType)
					.withOverrides(mapOfValuesOverride)
					.build();
			Test.stopTest();

			Foobar__c queriedFoobar = (Foobar__c)QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String>(mapOfValuesOverride.keySet()))
					.condition('Id').equals(sObjectInstance.Id)
					.getFirst();

			// Use dynamic get() methods for assertions
			Assert.isNotNull(queriedFoobar, 'The Foobar record should be inserted.');
			Assert.areEqual(TEST_STRING, queriedFoobar.get(SEL_Foobar.FIELD_TEXT), 'Foobar__c.Text__c should be set.');

			SObject level1Record = queriedFoobar.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP);
			Assert.isNotNull(level1Record, 'Level 1 related record should be created.');
			Assert.areEqual(TEST_STRING, level1Record.get(fieldName), 'Level 1 Name should be set.');

			SObject level2Record = level1Record.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP);
			Assert.isNotNull(level2Record, 'Level 2 related record should be created.');
			Assert.areEqual(TEST_STRING, level2Record.get(fieldName), 'Level 2 Name should be set.');

			SObject level3Record = level2Record.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP);
			Assert.isNotNull(level3Record, 'Level 3 related record should be created.');
			Assert.areEqual(TEST_STRING, level3Record.get(fieldName), 'Level 3 Name should be set.');

			SObject level4Record = level3Record.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP);
			Assert.isNotNull(level4Record, 'Level 4 related record should be created.');
			Assert.isNotNull(level4Record.get(fieldName), 'Level 4 Name should be auto-defaulted.');
		}
	}
	/**
	 * @description Tests building a Foobar__c in memory (doInsert=false) with related records defined using dot-notation.
	 */
	@IsTest
	private static void buildWithNestedMapRelationships()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Foobar__c foobarRecord = (Foobar__c)TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withOverrides
							(
									new Map<String, Object>
									{
											SEL_Foobar.FIELD_PARENT_NAME => TEST_STRING,
											SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + SEL_Foobar.FIELD_TEXT => TEST_STRING
									}
							)
					.withoutInsertion()
					.build();
			Test.stopTest();

			SObject relatedFoobar = foobarRecord.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP);
			Assert.isNotNull(relatedFoobar, 'Related Foobar__r should be created in memory.');
			Assert.areEqual(TEST_STRING, relatedFoobar.get(SEL_Foobar.FIELD_NAME), 'Foobar.Lookup__r.Name should be set from the map.');
			Assert.areEqual(TEST_STRING, relatedFoobar.get(SEL_Foobar.FIELD_TEXT), 'Foobar.Lookup__r.Text__c should be set from the map.');
		}
	}
	/**
	 * @description Tests building a Foobar__c in memory (doInsert=false) by passing a pre-existing, inserted SObject record (Foobar__c) as a relationship value.
	 */
	@IsTest
	private static void buildWithExistingSObjectAsRelationship()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Foobar__c insertedParent = (Foobar__c)TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withOverrides
							(
									new Map<SObjectField, Object>
									{
											Foobar__c.Name => TEST_STRING,
											Foobar__c.Text__c => TEST_STRING
									}
							)
					.build();

			Foobar__c childRecord = (Foobar__c)TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withOverrides
							(
									new Map<String, Object>
									{
											// Pass the SObject instance directly as the relationship value
											SEL_Foobar.RELATIONSHIP_LOOKUP => insertedParent
									}
							)
					.withoutInsertion()
					.build();

			Test.stopTest();

			Assert.isNotNull(childRecord.get(SEL_Foobar.FIELD_LOOKUP), 'Child Foobar.Lookup__c should be populated in memory.');
			Assert.areEqual(insertedParent.Id, childRecord.get(SEL_Foobar.FIELD_LOOKUP), 'Foobar.Lookup__c should be linked to the pre-existing inserted parent.');
			Assert.isNotNull(childRecord.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP), 'Child Foobar.Lookup__r should be populated in memory.');
			Assert.areEqual(insertedParent.Name, childRecord.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP).get(SEL_Foobar.FIELD_NAME), 'In-memory relationship should be correct.');
		}
	}
	/**
	 * @description Tests building and inserting a Foobar__c (doInsert=true) and successfully overriding a lookup field (OwnerId) with a specific Id value.
	 */
	@IsTest
	private static void buildAndInsertWithLookupOverride()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			SObject insertedSObject = TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(SEL_Foobar.FIELD_NAME, TEST_STRING)
					.withOverride('OwnerId', UserInfo.getUserId())
					.build();
			Test.stopTest();

			// Use the DAL method to find the record
			Foobar__c queriedFoobar = (Foobar__c)new SEL_Foobar().findById(insertedSObject.Id);

			Assert.areEqual(UserInfo.getUserId(), queriedFoobar.OwnerId, 'The OwnerId should be the one specified in the override map.');
		}
	}

	/**
	 * @description Tests the 'withOverrides(Map<SObjectField, Object>)' overload
	 * using SObjectField tokens for compile-time safety.
	 */
	@IsTest
	private static void buildWithSObjectFieldOverrides()
	{
		System.runAs(getTestAdmin())
		{
			final String testName = UTIL_Random.randomName();
			final String testText = UTIL_Random.randomName();

			Test.startTest();

			SObject sObjectInstance = TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, testName)
					.withOverride(Foobar__c.Text__c, testText)
					.withoutInsertion()
					.build();

			Test.stopTest();

			Assert.isNull(sObjectInstance?.Id, 'The built SObject Id should be null.');
			Assert.areEqual(testName, sObjectInstance.get(Foobar__c.Name), 'Name field should be set via SObjectField token.');
			Assert.areEqual(testText, sObjectInstance.get(Foobar__c.Text__c), 'Text__c field should be set via SObjectField token.');
		}
	}

	/**
	 * @description Tests building a list of Foobar__c in memory (doInsert=false) and verifies the list size.
	 */
	@IsTest
	private static void buildListWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			List<SObject> sObjectList = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.withoutInsertion()
					.buildList();

			Test.stopTest();

			Assert.isNotNull(sObjectList, 'The built SObject list should not be null.');
			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, sObjectList.size(), 'The list should contain the specified number of SObjects.');
		}
	}
	/**
	 * @description Tests building and inserting a list of 200 Foobar__c (doInsert=true) and verifies the list size.
	 */
	@IsTest
	private static void buildAndInsertLargeList()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 200;

			Test.startTest();

			List<SObject> sObjectList = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withCount(numberOfRecords)
					.buildList();

			Test.stopTest();

			Assert.isNotNull(sObjectList, 'The built SObject list should not be null.');
			Assert.areEqual(numberOfRecords, sObjectList.size(), 'The list should contain 200 SObjects.');
		}
	}
	/**
	 * @description Tests building a list of Foobar__c in memory (doInsert=false) while passing an empty override map and verifies the list size.
	 */
	@IsTest
	private static void buildListWithEmptyMapWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			// Passing an empty map is redundant, but this confirms it works.
			// A cleaner way is: .of(...).withCount(...).withoutInsertion().buildList()
			List<SObject> sObjectList = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withOverrides(new Map<String, Object>())
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.withoutInsertion()
					.buildList();

			Test.stopTest();

			Assert.isNotNull(sObjectList, 'The built SObject list should not be null.');
			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, sObjectList.size(), 'The list should contain the specified number of SObjects.');
		}
	}

	/**
	 * @description Tests building and inserting a list of Foobar__c, verifying list size.
	 */
	@IsTest
	private static void buildAndInsertListVerifiesIndexedDefaultValues()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			List<SObject> sObjectList = TST_Builder.of(Foobar__c.SObjectType)
					.withOverrides(new Map<String, Object>()) // Redundant, confirms empty map is fine
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.withoutInsertion()
					.buildList();

			Test.stopTest();

			Assert.isNotNull(sObjectList, 'The Foobar list should not be null.');
			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, sObjectList.size(), 'The list should contain correct number of Foobars.');
		}
	}
	/**
	 * @description Tests building a list of 10 Foobar__c in memory (doInsert=false), providing a List<Object> as an override value to populate fields cyclically.
	 */
	@IsTest
	private static void buildListWithListValueOverrideCyclical()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 10;

			Test.startTest();

			List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withOverrides
							(
									new Map<SObjectField, Object>
									{
											Foobar__c.Name => new List<String> {'test4', 'test3', 'test2', 'test1', 'test0'}
									}
							)
					.withCount(numberOfRecords)
					.withoutInsertion()
					.buildList();

			Test.stopTest();

			Assert.isNotNull(foobars, 'The Foobar list should not be null.');
			Assert.areEqual(numberOfRecords, foobars.size(), 'The list should contain 10 Foobars.');

			Assert.areEqual('test4', foobars.get(0).get(SEL_Foobar.FIELD_NAME), 'Name for index 0 should be test4.');
			Assert.areEqual('test3', foobars.get(1).get(SEL_Foobar.FIELD_NAME), 'Name for index 1 should be test3.');
			Assert.areEqual('test2', foobars.get(2).get(SEL_Foobar.FIELD_NAME), 'Name for index 2 should be test2.');
			Assert.areEqual('test1', foobars.get(3).get(SEL_Foobar.FIELD_NAME), 'Name for index 3 should be test1.');
			Assert.areEqual('test0', foobars.get(4).get(SEL_Foobar.FIELD_NAME), 'Name for index 4 should be test0.');
			Assert.areEqual('test4', foobars.get(5).get(SEL_Foobar.FIELD_NAME), 'Name for index 5 should cycle back to test4.');
			Assert.areEqual('test3', foobars.get(6).get(SEL_Foobar.FIELD_NAME), 'Name for index 6 should cycle back to test3.');
			Assert.areEqual('test2', foobars.get(7).get(SEL_Foobar.FIELD_NAME), 'Name for index 7 should cycle back to test2.');
			Assert.areEqual('test1', foobars.get(8).get(SEL_Foobar.FIELD_NAME), 'Name for index 8 should cycle back to test1.');
			Assert.areEqual('test0', foobars.get(9).get(SEL_Foobar.FIELD_NAME), 'Name for index 9 should cycle back to test0.');
		}
	}
	/**
	 * @description Tests building a list of 2 Foobar__c records in memory (doInsert=false),
	 * providing a List<SObject> (Foobar__c) as a related value to link records by index.
	 */
	@IsTest
	private static void buildListWithSObjectListAsRelationship()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			List<SObject> parentList = TST_Builder.of(Foobar__c.SObjectType)
					.withOverrides
							(
									new Map<SObjectField, Object>
									{
											Foobar__c.Name => TEST_STRING
									}
							)
					.withCount(2)
					.buildList(); // doInsert=true by default

			List<SObject> childList = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withOverrides
							(
									new Map<String, Object>
									{
											SEL_Foobar.RELATIONSHIP_LOOKUP => parentList
									}
							)
					.withCount(2)
					.withoutInsertion() // doInsert=false
					.buildList();

			Test.stopTest();

			Assert.areEqual(parentList.get(0).Id, childList.get(0).get(SEL_Foobar.FIELD_LOOKUP), 'Child 0 should be linked to Parent 0.');
			Assert.areEqual(parentList.get(1).Id, childList.get(1).get(SEL_Foobar.FIELD_LOOKUP), 'Child 1 should be linked to Parent 1.');
		}
	}
	/**
	 * @description Tests building and inserting a list of 5 Foobar__c, simultaneously creating 5 related Foobar__c records
	 */
	@IsTest
	private static void buildAndInsertListWithImplicitIndexedRelatedRecords()
	{
		System.runAs(getTestAdmin())
		{
			List<String> relatedNames = new List<String> {'Related [0]', 'Related [1]', 'Related [2]'};

			Test.startTest();

			TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withOverrides
							(
									new Map<String, Object>
									{
											SEL_Foobar.FIELD_PARENT_NAME => relatedNames
									}
							)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.buildList();

			Test.stopTest();

			List<SObject> relatedFoobars = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {SEL_Foobar.FIELD_NAME, SEL_Foobar.FIELD_EMAIL})
					.condition('Name').contains('Related [')
					.orderBy(SEL_Foobar.FIELD_NAME).ascending()
					.toList();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, relatedFoobars.size(), 'Should have created related parent records.');
			Assert.areEqual('Related [0]', relatedFoobars.get(0).get(SEL_Foobar.FIELD_NAME), 'Related record 0 Name should be indexed.');
			Assert.areEqual('Related [1]', relatedFoobars.get(1).get(SEL_Foobar.FIELD_NAME), 'Related record 1 Name should be indexed.');
			Assert.areEqual('Related [2]', relatedFoobars.get(2).get(SEL_Foobar.FIELD_NAME), 'Related record 2 Name should be indexed.');
		}
	}
	/**
	 * @description Tests the getter and setter for the global 'defaultValueProvider', ensuring it returns a default instance if set to null.
	 */
	@IsTest
	private static void defaultValueProviderGetterAndSetter()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isNotNull(TST_Builder.defaultValueProvider, 'Default value provider should not be null initially.');

			TST_Builder.defaultValueProvider = null;
			Assert.isNotNull(TST_Builder.defaultValueProvider, 'Default value provider should return a default instance even after being set to null.');

			TST_Builder.defaultValueProvider = new UTIL_SObjectBuilderDefaultProvider();
			Assert.isNotNull(TST_Builder.defaultValueProvider, 'Default value provider should be set to the new instance.');
		}
	}

	/**
	 * @description Tests that the DefaultValueProvider base class returns an empty map by default.
	 */
	@IsTest
	private static void defaultValueProviderBaseClassReturnsEmptyMap()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.DefaultValueProvider baseProvider = new TST_Builder.DefaultValueProvider();

			Map<String, TST_Builder.DefaultFieldValueProvider> result = baseProvider.getDefaultMapOfValues(Account.SObjectType, new Map<String, Object>());

			Assert.isTrue(result.isEmpty(), 'Base class should return an empty map');
		}
	}

	/**
	 * @description Tests that the DefaultFieldValueProvider base class returns null by default.
	 */
	@IsTest
	private static void defaultFieldValueProviderBaseClassReturnsNull()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.DefaultFieldValueProvider baseProvider = new TST_Builder.DefaultFieldValueProvider();

			Object result = baseProvider.getValue(0);

			Assert.isNull(result, 'Base class should return null');
		}
	}

	/**
	 * @description Tests the 'formatErrorMessage' utility method, verifying it correctly merges values and appends the original error message.
	 */
	@IsTest
	private static void utilFormatErrorMessage()
	{
		System.runAs(getTestAdmin())
		{
			Assert.areEqual('test1', formatErrorMessage('test{0}', new List<String> {'1'}, null), 'Should merge one value.');
			Assert.areEqual('test12', formatErrorMessage('test{0}{1}', new List<String> {'1', '2'}, null), 'Should merge two values.');
			Assert.areEqual
					(
							'test1\nOriginal error message : Error',
							formatErrorMessage('test{0}', new List<String> {'1'}, 'Error'),
							'Should merge one value and append the original error message.'
					);
		}
	}

	/**
	 * @description Tests the new 'build(SObjectType, List<Object>)' overload.
	 * It verifies that required fields (Name) and optional fields
	 * (Text__c, Email__c) specified in the list are all auto-defaulted.
	 * This test uses the 'doInsert=false' variant.
	 */
	@IsTest
	private static void buildWithAutoDefaultList()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			SObject newFoobar = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedField(SEL_Foobar.FIELD_NAME)
					.withDefaultedField(Foobar__c.Text__c) // SObjectField
					.withDefaultedField(SEL_Foobar.FIELD_EMAIL) // String
					.withoutInsertion()
					.build();
			Test.stopTest();

			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_NAME), 'Required field (Name) should still be defaulted.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Optional field (Text__c) from list should be defaulted.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_EMAIL), 'Optional field (Email__c) from list should be defaulted.');
		}
	}

	/**
	 * @description Tests the 'build(SObjectType, List<Object>, Map<String, Object>)' overload.
	 * It verifies that map values override list values, and that both
	 * lists and maps are applied correctly.
	 * This test uses the 'doInsert=false' variant.
	 */
	@IsTest
	private static void buildWithAutoDefaultListAndMapCombined()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithNameAndText();

			Map<String, Object> overrides = new Map<String, Object>
			{
					SEL_Foobar.FIELD_NAME => 'SpecificName', // Override value
					SEL_Foobar.FIELD_EMAIL => TEST_EMAIL // A new value
			};

			Test.startTest();
			SObject newFoobar = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedFields(fieldsToDefault)
					.withOverrides(overrides)
					.withoutInsertion()
					.build();
			Test.stopTest();

			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Optional field (Text__c) from list should be defaulted.');
			Assert.areEqual('SpecificName', newFoobar.get(SEL_Foobar.FIELD_NAME), 'Map override for Name should win over list default.');
			Assert.areEqual(TEST_EMAIL, newFoobar.get(SEL_Foobar.FIELD_EMAIL), 'Map value for Email__c should be set.');
		}
	}

	/**
	 * @description Tests using the 'autoDefaultFieldValueProvider' public property
	 * directly within a traditional override map.
	 */
	@IsTest
	private static void buildWithAutoDefaultProviderInMap()
	{
		System.runAs(getTestAdmin())
		{
			Map<String, Object> overrides = new Map<String, Object>
			{
					SEL_Foobar.FIELD_NAME => TST_Builder.autoDefaultFieldValueProvider,
					SEL_Foobar.FIELD_TEXT => TST_Builder.autoDefaultFieldValueProvider,
					SEL_Foobar.FIELD_LOOKUP => TST_Builder.autoDefaultFieldValueProvider,
					SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + SEL_Foobar.FIELD_NAME => TST_Builder.autoDefaultFieldValueProvider
			};

			Test.startTest();
			SObject newFoobar = TST_Builder.of(Foobar__c.SObjectType)
					.withOverrides(overrides)
					.withoutInsertion()
					.build();
			Test.stopTest();

			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_NAME), 'Required field (Name) should still be defaulted.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Optional field (Text__c) from provider map should be defaulted.');
			SObject relatedFoobar = newFoobar.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP);
			Assert.isNotNull(relatedFoobar, 'Related Foobar should be created because of the provider.');
			Assert.isNotNull(relatedFoobar.get(SEL_Foobar.FIELD_NAME), 'Related Foobar Name should be defaulted.');
		}
	}

	/**
	 * @description Tests that the 'createAutoDefaultMap' helper method gracefully
	 * handles invalid data types in the list (e.g., Integers, nulls)
	 * by silently ignoring them, as per its implementation.
	 */
	@IsTest
	private static void buildWithAutoDefaultListInvalidTypeIgnored()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = new List<Object>
			{
					SEL_Foobar.FIELD_NAME,
					SEL_Foobar.FIELD_TEXT, // Valid
					123, // Invalid - should be ignored
					null // Invalid - should be ignored
			};

			Test.startTest();
			SObject newFoobar = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedFields(fieldsToDefault)
					.withoutInsertion()
					.build();
			Test.stopTest();

			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Valid field (Text__c) should be defaulted.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_NAME), 'Required field (Name) should still be defaulted.');
		}
	}

	/**
	 * @description Tests 'build(String, List<Object>)' overload (default insert=true).
	 */
	@IsTest
	private static void buildWithAutoDefaultListStringDefaultInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithNameAndText();

			Test.startTest();
			SObject newFoobar = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedFields(fieldsToDefault)
					.build();
			Test.stopTest();

			Assert.isNotNull(newFoobar.Id, 'Record should be inserted by default.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_NAME), 'Required field Name should be defaulted.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c from list should be defaulted.');
		}
	}

	/**
	 * @description Tests 'build(String, List<Object>, Boolean)' overload (doInsert=false).
	 */
	@IsTest
	private static void buildWithAutoDefaultListStringWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithNameAndText();

			Test.startTest();
			SObject newFoobar = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withDefaultedFields(fieldsToDefault)
					.withoutInsertion()
					.build();
			Test.stopTest();

			Assert.isNull(newFoobar.Id, 'Record should not be inserted.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_NAME), 'Required field Name should be defaulted.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c from list should be defaulted.');
		}
	}

	/**
	 * @description Tests 'build(SObjectType, List<Object>, Map)' overload (default insert=true).
	 */
	@IsTest
	private static void buildWithAutoDefaultListAndMapSObjectTypeDefaultInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();
			Map<String, Object> overrides = new Map<String, Object> {SEL_Foobar.FIELD_EMAIL => TEST_EMAIL};

			Test.startTest();
			SObject newFoobar = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedFields(fieldsToDefault)
					.withOverrides(overrides)
					.build();
			Test.stopTest();

			Assert.isNotNull(newFoobar.Id, 'Record should be inserted by default.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c from list should be defaulted.');
			Assert.areEqual(TEST_EMAIL, newFoobar.get(SEL_Foobar.FIELD_EMAIL), 'Map override for Email__c should be set.');
		}
	}

	/**
	 * @description Tests 'build(String, List<Object>, Map)' overload (default insert=true).
	 */
	@IsTest
	private static void buildWithAutoDefaultListAndMapStringDefaultInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();
			Map<String, Object> overrides = new Map<String, Object> {SEL_Foobar.FIELD_EMAIL => TEST_EMAIL};

			Test.startTest();
			SObject newFoobar = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withDefaultedFields(fieldsToDefault)
					.withOverrides(overrides)
					.build();
			Test.stopTest();

			Assert.isNotNull(newFoobar.Id, 'Record should be inserted by default.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c from list should be defaulted.');
			Assert.areEqual(TEST_EMAIL, newFoobar.get(SEL_Foobar.FIELD_EMAIL), 'Map override for Email__c should be set.');
		}
	}

	/**
	 * @description Tests 'build(String, List<Object>, Map, Boolean)' overload (doInsert=false).
	 */
	@IsTest
	private static void buildWithAutoDefaultListAndMapStringWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();
			Map<String, Object> overrides = new Map<String, Object> {SEL_Foobar.FIELD_EMAIL => TEST_EMAIL};

			Test.startTest();
			SObject newFoobar = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withDefaultedFields(fieldsToDefault)
					.withOverrides(overrides)
					.withoutInsertion()
					.build();
			Test.stopTest();

			Assert.isNull(newFoobar.Id, 'Record should not be inserted.');
			Assert.isNotNull(newFoobar.get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c from list should be defaulted.');
			Assert.areEqual(TEST_EMAIL, newFoobar.get(SEL_Foobar.FIELD_EMAIL), 'Map override for Email__c should be set.');
		}
	}

	/**
	 * @description Tests 'build(SObjectType, List<Object>, Integer)' overload (default insert=true).
	 */
	@IsTest
	private static void buildListWithAutoDefaultListSObjectTypeDefaultInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();

			Test.startTest();
			List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedFields(fieldsToDefault)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, foobars.size(), 'List size should match.');
			Assert.isNotNull(foobars.get(0).Id, 'Records should be inserted by default.');
			Assert.isNotNull(foobars.get(0).get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c should be defaulted.');
		}
	}

	/**
	 * @description Tests 'build(String, List<Object>, Integer)' overload (default insert=true).
	 */
	@IsTest
	private static void buildListWithAutoDefaultListStringDefaultInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();

			Test.startTest();
			List<SObject> foobars = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withDefaultedFields(fieldsToDefault)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, foobars.size(), 'List size should match.');
			Assert.isNotNull(foobars.get(0).Id, 'Records should be inserted by default.');
			Assert.isNotNull(foobars.get(0).get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c should be defaulted.');
		}
	}

	/**
	 * @description Tests 'build(SObjectType, List<Object>, Integer, Boolean)' overload (doInsert=false).
	 */
	@IsTest
	private static void buildListWithAutoDefaultListSObjectTypeWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();

			Test.startTest();
			List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedFields(fieldsToDefault)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.withoutInsertion()
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, foobars.size(), 'List size should match.');
			Assert.isNull(foobars.get(0).Id, 'Records should not be inserted.');
			Assert.isNotNull(foobars.get(0).get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c should be defaulted.');
		}
	}

	/**
	 * @description Tests 'build(String, List<Object>, Integer, Boolean)' overload (doInsert=false).
	 */
	@IsTest
	private static void buildListWithAutoDefaultListStringWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();

			Test.startTest();
			List<SObject> foobars = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withDefaultedFields(fieldsToDefault)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.withoutInsertion()
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, foobars.size(), 'List size should match.');
			Assert.isNull(foobars.get(0).Id, 'Records should not be inserted.');
			Assert.isNotNull(foobars.get(0).get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c should be defaulted.');
		}
	}

	/**
	 * @description Tests 'build(SObjectType, List<Object>, Map, Integer)' overload (default insert=true).
	 */
	@IsTest
	private static void buildListWithAutoDefaultListAndMapSObjectTypeDefaultInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();
			Map<String, Object> overrides = new Map<String, Object> {SEL_Foobar.FIELD_EMAIL => TEST_EMAIL};

			Test.startTest();
			List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedFields(fieldsToDefault)
					.withOverrides(overrides)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, foobars.size(), 'List size should match.');
			Assert.isNotNull(foobars.get(0).Id, 'Records should be inserted by default.');
			Assert.isNotNull(foobars.get(0).get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c should be defaulted.');
			Assert.areEqual(TEST_EMAIL, foobars.get(0).get(SEL_Foobar.FIELD_EMAIL), 'Map override for Email__c should be set.');
		}
	}

	/**
	 * @description Tests 'build(String, List<Object>, Map, Integer)' overload (default insert=true).
	 */
	@IsTest
	private static void buildListWithAutoDefaultListAndMapStringDefaultInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();
			Map<String, Object> overrides = new Map<String, Object> {SEL_Foobar.FIELD_EMAIL => TEST_EMAIL};

			Test.startTest();
			List<SObject> foobars = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withDefaultedFields(fieldsToDefault)
					.withOverrides(overrides)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, foobars.size(), 'List size should match.');
			Assert.isNotNull(foobars.get(0).Id, 'Records should be inserted by default.');
			Assert.isNotNull(foobars.get(0).get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c should be defaulted.');
			Assert.areEqual(TEST_EMAIL, foobars.get(0).get(SEL_Foobar.FIELD_EMAIL), 'Map override for Email__c should be set.');
		}
	}

	/**
	 * @description Tests 'build(SObjectType, List<Object>, Map, Integer, Boolean)' overload (doInsert=false).
	 */
	@IsTest
	private static void buildListWithAutoDefaultListAndMapSObjectTypeWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();
			Map<String, Object> overrides = new Map<String, Object> {SEL_Foobar.FIELD_EMAIL => TEST_EMAIL};

			Test.startTest();
			List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedFields(fieldsToDefault)
					.withOverrides(overrides)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.withoutInsertion()
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, foobars.size(), 'List size should match.');
			Assert.isNull(foobars.get(0).Id, 'Records should not be inserted.');
			Assert.isNotNull(foobars.get(0).get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c should be defaulted.');
			Assert.areEqual(TEST_EMAIL, foobars.get(0).get(SEL_Foobar.FIELD_EMAIL), 'Map override for Email__c should be set.');
		}
	}

	/**
	 * @description Tests 'build(String, List<Object>, Map, Integer, Boolean)' overload (doInsert=false).
	 */
	@IsTest
	private static void buildListWithAutoDefaultListAndMapStringWithoutInsert()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> fieldsToDefault = createDefaultListWithText();
			Map<String, Object> overrides = new Map<String, Object> {SEL_Foobar.FIELD_EMAIL => TEST_EMAIL};

			Test.startTest();
			List<SObject> foobars = TST_Builder.of(SEL_Foobar.OBJECT_NAME)
					.withDefaultedFields(fieldsToDefault)
					.withOverrides(overrides)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.withoutInsertion()
					.buildList();
			Test.stopTest();

			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, foobars.size(), 'List size should match.');
			Assert.isNull(foobars.get(0).Id, 'Records should not be inserted.');
			Assert.isNotNull(foobars.get(0).get(SEL_Foobar.FIELD_TEXT), 'Optional field Text__c should be defaulted.');
			Assert.areEqual(TEST_EMAIL, foobars.get(0).get(SEL_Foobar.FIELD_EMAIL), 'Map override for Email__c should be set.');
		}
	}

	/**
	 * @description Tests the 'build(SObjectType, Map, Integer)' overload, which
	 * defaults to doInsert=true.
	 */
	@IsTest
	private static void buildListWithMapSObjectTypeDefaultInsert()
	{
		System.runAs(getTestAdmin())
		{
			Map<String, Object> mapOfValuesOverride = new Map<String, Object>
			{
					SEL_Foobar.FIELD_TEXT => TEST_STRING
			};

			Test.startTest();
			List<SObject> sObjectList = TST_Builder.of(Foobar__c.SObjectType)
					.withOverrides(mapOfValuesOverride)
					.withCount(SMALL_NUMBER_OF_RECORDS)
					.buildList();
			Test.stopTest();

			Assert.isNotNull(sObjectList, 'The built SObject list should not be null.');
			Assert.areEqual(SMALL_NUMBER_OF_RECORDS, sObjectList.size(), 'The list should contain the specified number of SObjects.');
			Assert.isNotNull(sObjectList.get(0).Id, 'Records should be inserted by default.');
			Assert.areEqual(TEST_STRING, sObjectList.get(0).get(SEL_Foobar.FIELD_TEXT), 'Override map should be applied.');
		}
	}

	/**
	 * @description Tests that building an SObject with an invalid/non-existent SObject API name ('TEST') correctly throws an exception.
	 */
	@IsTest
	private static void buildWithInvalidSObjectNameThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();
				TST_Builder.of(TEST_STRING).build();
				Test.stopTest();

				Assert.fail('Expected an exception for an invalid SObject name, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsTypeException(error, 'Invalid exception for an invalid SObject name.');
			}
		}
	}

	/**
	 * @description Tests that building an SObject with an null SObjectType correctly throws an exception.
	 */
	@IsTest
	private static void buildWithNullSObjectTypeThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				final SObjectType nullType = null;

				Test.startTest();

				TST_Builder.of(nullType).build();

				Test.stopTest();

				Assert.fail('Expected an exception for an invalid SObjectType but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Invalid exception for an invalid SObjectType.');
			}
		}
	}

	/**
	 * @description Tests that building an SObject with an invalid String name throws a descriptive IllegalArgumentException.
	 */
	@IsTest
	private static void buildWithInvalidStringNameThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Builder.of('NonExistentObject__c').build();

				Test.stopTest();

				Assert.fail('Expected an exception for an invalid SObject name but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Invalid exception for an invalid SObject name.');
				Assert.isTrue(error.getMessage().contains('NonExistentObject__c'), 'Error message should contain the invalid name');
			}
		}
	}

	/**
	 * @description Tests that building an SObject with a blank String name throws a descriptive IllegalArgumentException.
	 */
	@IsTest
	private static void buildWithBlankStringNameThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Builder.of('').build();

				Test.stopTest();

				Assert.fail('Expected an exception for a blank SObject name but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Invalid exception for a blank SObject name.');
				Assert.isTrue(error.getMessage().contains('blank'), 'Error message should mention blank');
			}
		}
	}

	/**
	 * @description Tests that attempting to build an object that is not creatable (Profile) correctly throws an SObjectBuilderException.
	 * @note This test does not perform DML and is safe to run.
	 */
	@IsTest
	private static void buildNonCreatableSObjectThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();
				// Profile is not creatable, this is expected to fail before DML
				TST_Builder.of(Profile.SObjectType).build();
				Test.stopTest();

				Assert.fail('Expected an SObjectBuilderException for a non-creatable object, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsTypeException(error, 'Expected an SObjectBuilderException when building a Profile object.');
			}
		}
	}
	/**
	 * @description Tests that attempting to build a Foobar__c without its required Name field (by passing null)
	 * correctly throws a DmlException during insertion.
	 */
	@IsTest
	private static void buildWithoutRequiredFieldsThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				// Instead, force a DmlException with a non-existent lookup ID.
				String mockId = UTIL_Random.randomId(Foobar__c.SObjectType);

				TST_Builder.of(Foobar__c.SObjectType)
						.withOverrides(new Map<String, Object>
						{
								SEL_Foobar.FIELD_LOOKUP => mockId
						})
						.build();

				Test.stopTest();

				Assert.fail('Expected a DmlException for missing required fields, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsDmlException(error, 'Expected an DmlException when building a Foobar__c without a Name.');
			}
		}
	}

	/**
	 * @description Tests building an Account in an org with Person Accounts enabled, ensuring the default Record TypeId is handled
	 * correctly without throwing an exception. Uses doInsert=false to avoid DML.
	 */
	@IsTest
	private static void buildAccountWithPersonAccountsEnabled()
	{
		System.runAs(getTestAdmin())
		{
			if(UTIL_SObjectDescribe.isPersonAccountEnabled())
			{
				Exception caughtException;

				try
				{
					Test.startTest();
					// Build in-memory only to test logic without risking DML failure
					TST_Builder.of(SEL_Foobar.OBJECT_NAME).withoutInsertion().build();
					Test.stopTest();
				}
				catch(Exception error)
				{
					caughtException = error;
				}

				Assert.isNull(caughtException, 'Building a record (doInsert=false) in a Person Account org should not throw an exception.');
			}
		}
	}
	/**
	 * @description Tests that attempting to build an Account with an invalid RecordTypeId string ('BadId')
	 * correctly throws an SObjectBuilderException.
	 */
	@IsTest
	private static void buildWithInvalidRecordTypeIdStringThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_SObjectBuilderDefaultProvider.isMockActive = true;
			UTIL_SObjectBuilderDefaultProvider.mockPersonAccountsAreEnabled = true;
			UTIL_SObjectBuilderDefaultProvider.mockPersonAccountRecordTypeIds = new Set<Id> {};

			try
			{
				Test.startTest();

				TST_Builder.of(Account.SObjectType)
						.withOverrides
								(
										new Map<String, Object>
										{
												'RecordTypeId' => 'BadId'
										}
								)
						.withoutInsertion()
						.build();

				Test.stopTest();

				Assert.fail('Expected an IllegalArgumentException for an invalid RecordTypeId string, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Successfully caught an exception for an invalid RecordTypeId string.');
			}
		}
	}
	/**
	 * @description Tests that attempting to build a Foobar__c with a non-existent field ('Test')
	 * in the override map correctly throws an SObjectBuilderException.
	 */
	@IsTest
	private static void buildWithNonExistentFieldThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();
				TST_Builder.of(SEL_Foobar.OBJECT_NAME)
						.withOverrides
								(
										new Map<String, Object>
										{
												TEST_STRING => TEST_STRING
										}
								)
						.build();
				Test.stopTest();

				Assert.fail('Expected an SObjectBuilderException for a non-existent field, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'Expected an SObjectBuilderException when providing a non-existent field.');
			}
		}
	}
	/**
	 * @description Tests that attempting to build a Foobar__c with a non-existent related field ('Lookup__r.Test')
	 * in the override map correctly throws an SObjectBuilderException.
	 */
	@IsTest
	private static void buildWithNonExistentRelatedFieldThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();
				TST_Builder.of(Foobar__c.SObjectType)
						.withOverrides
								(
										new Map<String, Object>
										{
												SEL_Foobar.RELATIONSHIP_LOOKUP + '.Test' => TEST_STRING
										}
								)
						.build();
				Test.stopTest();

				Assert.fail('Expected an SObjectBuilderException for a non-existent related field, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'Expected an SObjectBuilderException when providing a non-existent related field.');
			}
		}
	}
	/**
	 * @description Tests that attempting to build a Foobar__c with a non-existent relationship
	 * ('Lookup__r.Lookup__r.Test.Id') in the override map correctly throws an SObjectBuilderException.
	 */
	@IsTest
	private static void buildWithNonExistentRelationshipPathThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();
				TST_Builder.of(SEL_Foobar.OBJECT_NAME)
						.withOverrides(new Map<String, Object>
						{
								SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + SEL_Foobar.RELATIONSHIP_LOOKUP + '.Test.Id' => TEST_STRING
						})
						.build();
				Test.stopTest();

				Assert.fail('Expected an SObjectException for a non-existent relationship path, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'Expected an SObjectException when providing a non-existent relationship path.');
			}
		}
	}
	/**
	 * @description Tests that attempting to build a Foobar__c with an incorrect data type for a field (Date for a String field 'Text__c')
	 * correctly throws an exception.
	 */
	@IsTest
	private static void buildWithIncorrectFieldTypeThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();
				TST_Builder.of(SEL_Foobar.OBJECT_NAME)
						.withOverrides
								(
										new Map<String, Object>
										{
												SEL_Foobar.FIELD_TEXT => Date.today()
										}
								)
						.build();
				Test.stopTest();

				Assert.fail('Expected an SObjectBuilderException for an incorrect field value type, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'Expected an SObjectBuilderException when providing an incorrect field value type.');
			}
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'SObjectFactory' constructor, if null SObject Type is passed, then it should throw an exception
	 */
	@IsTest
	private static void factorySObjectThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new TST_BuilderInternal.SObjectFactory(null);
				Assert.fail('Expected an Exception for a null SObject Type, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Expected an Illegal Argument Exception when passing a null SObject Type.');
			}
		}
	}

	/**
	 * @description Tests the 'withOptionalField(String)' builder method.
	 * It builds a Case, explicitly marking 'BusinessHoursId' (a setup object)
	 * as optional to prevent the provider from trying to create it.
	 */
	@IsTest
	private static void buildWithOptionalFieldString()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
					.withOptionalField('BusinessHoursId')
					.withoutInsertion()
					.build();

			Test.stopTest();

			Assert.isNull(caseRecord.BusinessHoursId, 'BusinessHoursId should be null as it was marked optional.');
		}
	}

	/**
	 * @description Tests the 'withOptionalField(SObjectField)' builder method.
	 * This verifies that the SObjectField token overload works correctly.
	 */
	@IsTest
	private static void buildWithOptionalFieldToken()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			// Test the SObjectField token version of the method
			Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
					.withOptionalField(Case.BusinessHoursId)
					.withoutInsertion()
					.build();

			Test.stopTest();

			Assert.isNull(caseRecord.BusinessHoursId, 'BusinessHoursId should be null as it was marked optional.');
		}
	}

	/**
	 * @description Tests the 'withOptionalFields(List<Object>)' builder method.
	 * It ensures a list containing both Strings and SObjectField tokens is processed.
	 */
	@IsTest
	private static void buildWithOptionalFieldsList()
	{
		System.runAs(getTestAdmin())
		{
			// Define a list with mixed types (String and SObjectField)
			List<Object> optionalFields = new List<Object>
			{
					Case.BusinessHoursId.getDescribe().name, // Test String
					Case.EntitlementId // Test SObjectField token
			};

			Test.startTest();

			Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
					.withOptionalFields(optionalFields)
					.withoutInsertion()
					.build();

			Test.stopTest();

			Assert.isNull(caseRecord.BusinessHoursId, 'BusinessHoursId should be null.');
			Assert.isNull(caseRecord.EntitlementId, 'EntitlementId should be null.');
		}
	}

	/**
	 * @description Verifies that the 'buildList()' method's finally block
	 * correctly restores the global 'TST_Builder.optionalFields' list
	 * to its original state, ensuring test isolation.
	 */
	@IsTest
	private static void buildWithOptionalFieldsCleansUpGlobalList()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.optionalFields.clear();
			Assert.isTrue(TST_Builder.optionalFields.isEmpty(), 'Global list should be empty before build.');

			Test.startTest();

			TST_Builder.of(Case.SObjectType)
					.withOptionalField(Case.BusinessHoursId)
					.withoutInsertion()
					.build();

			Test.stopTest();

			Assert.isTrue(TST_Builder.optionalFields.isEmpty(), 'Global list should be empty after build, due to cleanup logic.');
		}
	}

	/**
	 * @description Verifies that the cleanup logic also works when the global list was *not* empty to begin with.
	 */
	@IsTest
	private static void buildWithOptionalFieldsRestoresGlobalList()
	{
		System.runAs(getTestAdmin())
		{
			TST_Builder.optionalFields.add('SomeOtherField__c');
			Assert.areEqual(1, TST_Builder.optionalFields.size(), 'Global list should have one item before build.');

			Test.startTest();

			TST_Builder.of(Case.SObjectType)
					.withOptionalField(Case.BusinessHoursId) // This is added *during* the build
					.withoutInsertion()
					.build();

			Test.stopTest();

			Assert.areEqual(1, TST_Builder.optionalFields.size(), 'Global list should be restored to its original size.');
			Assert.areEqual('SomeOtherField__c', TST_Builder.optionalFields.get(0), 'Global list should contain its original item.');
		}
	}

	/**
	 * @description Tests building a list in memory (doInsert=false) and providing
	 * a List<SObject> for a *read-only* relationship (`Case.Parent`).
	 * This verifies the heuristic correctly identifies 'Parent' as a ListFieldDefaultValue
	 * (due to __r) and that the SObjectFactory correctly routes the read-only
	 * values to the mocking engine for indexed assignment.
	 */
	@IsTest
	private static void buildListWithReadOnlySObjectListAsRelationship()
	{
		System.runAs(getTestAdmin())
		{
			// 1. Create mock parent records (in-memory)
			// We only need the Ids for the read-only linking
			List<SObject> parentCases = new List<SObject>
			{
					new Case(Id = UTIL_Random.randomId(Case.SObjectType), Subject = 'Parent 1'),
					new Case(Id = UTIL_Random.randomId(Case.SObjectType), Subject = 'Parent 2')
			};

			// 2. Build child cases without insertion
			Test.startTest();
			List<SObject> childCases = TST_Builder.of(Case.SObjectType)
					.withOverrides(new Map<String, Object>
					{
							// Pass the List<SObject> to the read-only 'Parent' relationship
							'Parent' => parentCases
					})
					.withCount(2)
					.withoutInsertion()
					.buildList();
			Test.stopTest();

			// 3. Verify
			Assert.areEqual(2, childCases.size(), 'Should build 2 child cases.');

			Case child1 = (Case)childCases.get(0);
			Case child2 = (Case)childCases.get(1);
			Case parent1 = (Case)parentCases.get(0);
			Case parent2 = (Case)parentCases.get(1);

			// Verify Child 1 is linked to Parent 1
			Assert.isNotNull(child1.Parent, 'Child 1 Parent relationship should be mocked.');
			Assert.areEqual(parent1.Id, child1.ParentId, 'Child 1 ParentId should be set.');
			Assert.areEqual(parent1.Id, child1.Parent.Id, 'Child 1 Parent.Id should be set.');

			// Verify Child 2 is linked to Parent 2
			Assert.isNotNull(child2.Parent, 'Child 2 Parent relationship should be mocked.');
			Assert.areEqual(parent2.Id, child2.ParentId, 'Child 2 ParentId should be set.');
			Assert.areEqual(parent2.Id, child2.Parent.Id, 'Child 2 Parent.Id should be set.');
		}
	}

	@IsTest
	private static void buildAccountWithContactChildrenAndVerifyRelationship()
	{
		System.runAs(getTestAdmin())
		{
			// Test single parent with children (with DML)
			Test.startTest();
			Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Test Parent')
					.withChildren
							(
									Foobar__c.SObjectType,
									3,
									new Map<SObjectField, Object>
									{
											Foobar__c.Name => 'Child'
									}
							)
					.build();
			Test.stopTest();

			// Verify parent inserted
			Assert.isNotNull(parent.Id, 'Parent should be inserted');
			Assert.areEqual('Test Parent', parent.Name, 'Parent name should match');

			List<Foobar__c> children = new SEL_Foobar().findByParentId(parent.Id);
			Assert.areEqual(3, children.size(), 'Should have 3 children');
			Assert.areEqual('Child', children[0].Name, 'Child name should match');
			Assert.areEqual(parent.Id, children[0].Lookup__c, 'Child should be linked to parent');
		}
	}

	@IsTest
	private static void buildAccountWithMockedContactChildrenWithoutDML()
	{
		System.runAs(getTestAdmin())
		{
			// Test in-memory graph (without DML)
			Test.startTest();
			Account account = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Name, 'Test Account')
					.withChildren
							(
									Contact.SObjectType,
									2,
									new Map<SObjectField, Object>
									{
											Contact.LastName => 'Smith'
									}
							)
					.withoutInsertion()
					.build();
			Test.stopTest();

			// Verify parent not inserted
			Assert.isNull(account.Id, 'Account should not be inserted');

			// Verify children mocked via JSON
			Assert.isNotNull(account.Contacts, 'Contacts relationship should exist');
			Assert.areEqual(2, account.Contacts.size(), 'Should have 2 contacts via JSON mocking');
			Assert.areEqual('Smith', account.Contacts[0].LastName, 'Contact last name should match');
			Assert.isNull(account.Contacts[0].Id, 'Contact should not be inserted');
		}
	}

	@IsTest
	private static void buildAccountWithMultipleChildTypesContactsAndCases()
	{
		System.runAs(getTestAdmin())
		{
			// Test single child type with self-referential relationship
			Test.startTest();

			Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Multi-Child Parent')
					.withChildren
							(
									Foobar__c.SObjectType,
									5,
									new Map<SObjectField, Object>
									{
											Foobar__c.Name => 'Child Record'
									}
							)
					.build();
			Test.stopTest();

			List<Foobar__c> children = new SEL_Foobar().findByParentId(parent.Id);
			Assert.areEqual(5, children.size(), 'Should have 5 children');
			Assert.areEqual('Child Record', children[0].Name, 'Child name should match');
		}
	}

	@IsTest
	private static void buildAccountWithChildrenUsingBuilderVariant()
	{
		System.runAs(getTestAdmin())
		{
			// Test using Builder variant for complex configuration
			// Using SObjectType variant instead of string name for self-relationship
			Test.startTest();
			Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Complex Parent')
					.withChildren
							(
									Foobar__c.SObjectType,
									2,
									new Map<SObjectField, Object>
									{
											Foobar__c.Name => 'Builder Child'
									}
							)
					.build();
			Test.stopTest();

			List<Foobar__c> children = new SEL_Foobar().findByParentId(parent.Id);
			Assert.areEqual(2, children.size(), 'Should have 2 children');
			Assert.areEqual('Builder Child', children[0].Name, 'Child name should match');
		}
	}

	@IsTest
	private static void buildWithChildrenThrowsExceptionForNullChildType()
	{
		System.runAs(getTestAdmin())
		{
			// Test null child type

			Test.startTest();
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withChildren(null, 1, new Map<SObjectField, Object>());
				Assert.fail('Should have thrown IllegalArgumentException');
			}
			catch(Exception error)
			{
				Test.stopTest();
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for null child type');
				Assert.isTrue(error.getMessage().contains('Child SObjectType cannot be null'), 'Error message should be clear');
			}
		}
	}

	@IsTest
	private static void buildWithChildrenThrowsExceptionForInvalidCount()
	{
		System.runAs(getTestAdmin())
		{
			// Test invalid count

			Test.startTest();
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withChildren(Foobar__c.SObjectType, 0, new Map<SObjectField, Object>());
				Assert.fail('Should have thrown IllegalArgumentException');
			}
			catch(Exception error)
			{
				Test.stopTest();
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for invalid count');
				Assert.isTrue(error.getMessage().contains('Count must be at least 1'), 'Error message should be clear');
			}
		}
	}

	@IsTest
	private static void buildWithChildrenThrowsExceptionForBlankRelationshipName()
	{
		System.runAs(getTestAdmin())
		{
			// Test blank relationship name in Builder variant

			Test.startTest();
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withChildren('', TST_Builder.of(Foobar__c.SObjectType));
				Assert.fail('Should have thrown IllegalArgumentException');
			}
			catch(Exception error)
			{
				Test.stopTest();
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for blank relationship name');
			}
		}
	}

	@IsTest
	private static void buildWithChildrenThrowsExceptionForNullBuilder()
	{
		System.runAs(getTestAdmin())
		{
			// Test null builder in Builder variant

			Test.startTest();
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withChildren(SEL_Foobar.RELATIONSHIP_FOOBARS, null);
				Assert.fail('Should have thrown IllegalArgumentException');
			}
			catch(Exception error)
			{
				Test.stopTest();
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for null builder');
			}
		}
	}

	@IsTest
	private static void buildMultipleParentsWithChildren()
	{
		System.runAs(getTestAdmin())
		{
			// Test bulk generation with self-referential relationship using fluent API
			Test.startTest();
			List<Foobar__c> parents = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(3)
					.withOverride(Foobar__c.Name, 'Bulk Parent')
					.withChildren
							(
									Foobar__c.SObjectType,
									2,
									new Map<SObjectField, Object>
									{
											Foobar__c.Name => 'Graph Child'
									}
							)
					.buildList();
			Test.stopTest();

			// Verify parents
			Assert.areEqual(3, parents.size(), 'Should have 3 parents');
			Assert.isNotNull(parents[0].Id, 'Parents should be inserted');

			for(Foobar__c parent : parents)
			{
				List<Foobar__c> children = new SEL_Foobar().findByParentId(parent.Id);
				Assert.areEqual(2, children.size(), 'Each parent should have 2 children');
			}
		}
	}

	@IsTest
	private static void buildMultipleParentsWithoutChildren()
	{
		System.runAs(getTestAdmin())
		{
			// Test building multiple parents without children using fluent API
			Test.startTest();
			List<Foobar__c> parents = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(2)
					.withOverride(Foobar__c.Name, 'No Children')
					.buildList();
			Test.stopTest();

			Assert.areEqual(2, parents.size(), 'Should have 2 parents');
			Assert.isNotNull(parents[0].Id, 'Parents should be inserted');
		}
	}

	@IsTest
	private static void buildWithChildrenSimpleVariantWithoutOverrides()
	{
		System.runAs(getTestAdmin())
		{
			// Test Tier 1: withChildren(SObjectType, Integer) without field overrides
			Test.startTest();
			Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Simple Parent')
					.withChildren(Foobar__c.SObjectType, 2)
					.build();
			Test.stopTest();

			Assert.isNotNull(parent.Id, 'Parent should be inserted');
			Assert.areEqual('Simple Parent', parent.Name, 'Parent name should match');

			List<Foobar__c> children = new SEL_Foobar().findByParentId(parent.Id);
			Assert.areEqual(2, children.size(), 'Should have 2 children');
			Assert.areEqual(parent.Id, children[0].Lookup__c, 'Child should be linked to parent');
		}
	}

	@IsTest
	private static void buildWithChildrenBuilderVariantAutoDetect()
	{
		System.runAs(getTestAdmin())
		{
			// Test Tier 3: withChildren(Builder) with auto-detected relationship name
			Test.startTest();
			Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Auto Parent')
					.withChildren
							(
									TST_Builder.of(Foobar__c.SObjectType)
											.withCount(3)
											.withOverride(Foobar__c.Name, 'Auto Child')
							)
					.build();
			Test.stopTest();

			Assert.isNotNull(parent.Id, 'Parent should be inserted');
			Assert.areEqual('Auto Parent', parent.Name, 'Parent name should match');

			List<Foobar__c> children = new SEL_Foobar().findByParentId(parent.Id);
			Assert.areEqual(3, children.size(), 'Should have 3 children');
			Assert.areEqual('Auto Child', children[0].Name, 'Child name should match');
			Assert.areEqual(parent.Id, children[0].Lookup__c, 'Child should be linked to parent');
		}
	}

	@IsTest
	private static void buildWithChildrenThrowsExceptionForNullChildTypeWithStringOverrides()
	{
		System.runAs(getTestAdmin())
		{
			// Test null childType with String overrides variant (line 665)

			Test.startTest();
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withChildren(null, 2, new Map<String, Object> {'Name' => 'Test'});
				Assert.fail('Should have thrown IllegalArgumentException');
			}
			catch(Exception error)
			{
				Test.stopTest();
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for null childType');
				Assert.isTrue(error.getMessage().contains('cannot be null'), 'Error message should mention null');
			}
		}
	}

	@IsTest
	private static void buildWithChildrenThrowsExceptionForInvalidParentChildRelationship()
	{
		System.runAs(getTestAdmin())
		{
			// Test invalid parent-child relationship (line 937)
			// Contact cannot have Account as a child

			Test.startTest();
			try
			{
				TST_Builder.of(Contact.SObjectType)
						.withChildren
								(
										Account.SObjectType,
										1,
										new Map<SObjectField, Object>
										{
												Account.Name => 'Test'
										}
								)
						.build();
				Assert.fail('Should have thrown IllegalArgumentException');
			}
			catch(Exception error)
			{
				Test.stopTest();
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for invalid relationship');
				Assert.isTrue(error.getMessage().contains('No child relationship found'), 'Error message should mention relationship not found');
			}
		}
	}

	@IsTest
	private static void buildWithChildrenThrowsExceptionForInvalidRelationshipName()
	{
		System.runAs(getTestAdmin())
		{
			// Test invalid relationship name in Builder variant (line 962)

			Test.startTest();
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withChildren
								(
										'InvalidRelationshipName',
										TST_Builder.of(Foobar__c.SObjectType)
												.withOverride(Foobar__c.Name, 'Test')
								)
						.build();
				Assert.fail('Should have thrown IllegalArgumentException');
			}
			catch(Exception error)
			{
				Test.stopTest();
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for invalid relationship name');
				Assert.isTrue(error.getMessage().contains('No relationship found'), 'Error message should mention relationship not found');
			}
		}
	}

	@IsTest
	private static void buildWithChildrenBuilderVariantThrowsExceptionForNullBuilder()
	{
		System.runAs(getTestAdmin())
		{
			// Test null builder in auto-detect Builder variant (line 738)

			Test.startTest();
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withChildren((TST_Builder.Builder)null);
				Assert.fail('Should have thrown IllegalArgumentException');
			}
			catch(Exception error)
			{
				Test.stopTest();
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for null builder');
				Assert.isTrue(error.getMessage().contains('Child builder cannot be null'), 'Error message should mention null builder');
			}
		}
	}

	/**
	 * @description Tests that using withChildren with a custom factory provider that doesn't support
	 * FactoryWithChildren throws an appropriate error.
	 */
	@IsTest
	private static void shouldThrowErrorWhenFactoryProviderDoesNotSupportChildren()
	{
		System.runAs(getTestAdmin())
		{
			// Set a custom factory provider that doesn't support children
			TST_Builder.factoryProvider = new LegacyFactoryProvider();

			Test.startTest();

			try
			{
				// This should throw UnsupportedOperationException
				TST_Builder.of(Foobar__c.SObjectType)
						.withChildren(Foobar__c.SObjectType, 1, new Map<String, Object> {'Name' => 'Test'})
						.buildList();

				Assert.fail('Expected UnsupportedOperationException to be thrown');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UnsupportedOperationException.class, 'Incorrect Exception Type Thrown');
				Assert.isTrue(error.getMessage().contains('does not support child relationships'), 'Error message should mention child relationships');
				Assert.isTrue(error.getMessage().contains('FactoryWithChildren'), 'Error message should mention the required interface');
			}

			Test.stopTest();
		}
	}

	/**
	 * @description Tests that attempting to use 'withChildren(Builder)' (auto-detect)
	 * between two objects with multiple relationships (e.g., User -> User via ManagerId, DelegatedApproverId)
	 * throws an IllegalArgumentException because the relationship is ambiguous.
	 */
	@IsTest
	private static void buildWithChildrenAmbiguousRelationshipThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				// User object typically has multiple named self-referential relationships (e.g., ManagerId, DelegatedApproverId).
				// This ambiguity should prevent the builder from auto-detecting which one to use.
				TST_Builder.of(User.SObjectType)
						.withChildren
								(
										TST_Builder.of(User.SObjectType)
												.withOverride(User.LastName, 'Child User')
								)
						.withoutInsertion() // Avoid User DML/Required fields complexity
						.build();

				Test.stopTest();

				Assert.fail('Expected IllegalArgumentException for ambiguous child relationships (User -> User).');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Should throw exception for multiple User-User relationships');
				Assert.isTrue(error.getMessage().contains('Multiple relationships found'), 'Error message should mention multiple relationships');
				Assert.isTrue(error.getMessage().contains('User'), 'Error message should mention the object type');
			}
		}
	}

	/**
	 * @description Verifies withoutInsertion(true) assigns a mock ID to a single record
	 */
	@IsTest
	private static void withoutInsertionTrueShouldAssignMockIdToSingleRecord()
	{
		System.runAs(getTestAdmin())
		{
			//Build with mock IDs enabled
			Foobar__c result = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Test')
					.withoutInsertion(true)
					.build();

			//Record should have a valid mock ID
			Assert.isNotNull(result.Id, 'Record should have a mock ID');
			Assert.areEqual(Foobar__c.SObjectType, result.Id.getSobjectType(), 'Mock ID should be for correct SObjectType');
		}
	}

	/**
	 * @description Verifies withoutInsertion(true) assigns unique mock IDs to multiple records
	 */
	@IsTest
	private static void withoutInsertionTrueShouldAssignUniqueMockIdsToMultipleRecords()
	{
		System.runAs(getTestAdmin())
		{
			//Build multiple records with mock IDs enabled
			List<Foobar__c> results = TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Test')
					.withCount(5)
					.withoutInsertion(true)
					.buildList();

			//All records should have unique mock IDs
			Set<Id> mockIds = new Set<Id>();
			for(Foobar__c record : results)
			{
				Assert.isNotNull(record.Id, 'Each record should have a mock ID');
				mockIds.add(record.Id);
			}
			Assert.areEqual(5, mockIds.size(), 'All mock IDs should be unique');
		}
	}

	/**
	 * @description Verifies withoutInsertion(true) assigns mock IDs to parent and children
	 */
	@IsTest
	private static void withoutInsertionTrueShouldAssignMockIdsToParentAndChildren()
	{
		System.runAs(getTestAdmin())
		{
			//Build parent with children and mock IDs enabled
			Account result = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Name, 'Test Account')
					.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
					{
							Contact.LastName => 'Test Contact'
					})
					.withoutInsertion(true)
					.build();

			//Parent should have a mock ID
			Assert.isNotNull(result.Id, 'Parent should have a mock ID');
			Assert.areEqual(Account.SObjectType, result.Id.getSobjectType(), 'Parent mock ID should be for Account');

			//Children should have mock IDs
			List<Contact> contacts = result.Contacts;
			Assert.areEqual(3, contacts.size(), 'Should have 3 children');

			Set<Id> childMockIds = new Set<Id>();
			for(Contact aContact : contacts)
			{
				Assert.isNotNull(aContact.Id, 'Each child should have a mock ID');
				Assert.areEqual(Contact.SObjectType, aContact.Id.getSobjectType(), 'Child mock ID should be for Contact');
				childMockIds.add(aContact.Id);
			}
			Assert.areEqual(3, childMockIds.size(), 'All child mock IDs should be unique');
		}
	}

	/**
	 * @description Verifies withoutInsertion(true) assigns mock IDs to auto-created parent records via withDefaultedField
	 */
	@IsTest
	private static void withoutInsertionTrueShouldAssignMockIdsToDefaultedParentRecords()
	{
		System.runAs(getTestAdmin())
		{
			//Build with a defaulted lookup field and mock IDs enabled
			Case result = (Case)TST_Builder.of(Case.SObjectType)
					.withDefaultedField(Case.AccountId)
					.withoutInsertion(true)
					.build();

			//Main record should have a mock ID
			Assert.isNotNull(result.Id, 'Case should have a mock ID');
			Assert.areEqual(Case.SObjectType, result.Id.getSobjectType(), 'Case mock ID should be for Case');

			//Parent Account should have a mock ID
			Assert.isNotNull(result.Account, 'Account relationship should be populated');
			Assert.isNotNull(result.Account.Id, 'Parent Account should have a mock ID');
			Assert.areEqual(Account.SObjectType, result.Account.Id.getSobjectType(), 'Account mock ID should be for Account');

			//AccountId should match the parent's mock ID
			Assert.areEqual(result.Account.Id, result.AccountId, 'AccountId should reference the parent Account mock ID');
		}
	}

	/**
	 * @description Verifies withoutInsertion(false) does not assign mock IDs (same as withoutInsertion())
	 */
	@IsTest
	private static void withoutInsertionFalseShouldNotAssignMockIds()
	{
		System.runAs(getTestAdmin())
		{
			//Build with mock IDs explicitly disabled
			Foobar__c result = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Test')
					.withoutInsertion(false)
					.build();

			//Record should not have an ID
			Assert.isNull(result.Id, 'Record should not have a mock ID when withoutInsertion(false)');
		}
	}

	/**
	 * @description Verifies the global mock ID flag is properly reset after build
	 */
	@IsTest
	private static void globalMockIdFlagShouldBeResetAfterBuild()
	{
		System.runAs(getTestAdmin())
		{
			//Global flag should start as false
			Assert.isFalse(TST_BuilderInternal.globalGenerateMockIds, 'Global flag should start as false');

			//Build with mock IDs enabled
			TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Test')
					.withoutInsertion(true)
					.build();

			//Global flag should be reset to false
			Assert.isFalse(TST_BuilderInternal.globalGenerateMockIds, 'Global flag should be reset after build');
		}
	}

	/**
	 * @description Verifies the global mock ID flag is reset even if build throws an exception
	 */
	@IsTest
	private static void globalMockIdFlagShouldBeResetEvenOnException()
	{
		System.runAs(getTestAdmin())
		{
			//Global flag should start as false
			Assert.isFalse(TST_BuilderInternal.globalGenerateMockIds, 'Global flag should start as false');

			//Build with invalid configuration that causes an exception
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withOverride('InvalidField__c', 'Test')
						.withoutInsertion(true)
						.build();

				Assert.fail('Expected exception to be thrown');
			}
			catch(Exception ignoredException)
			{
				//Global flag should still be reset to false
				Assert.isFalse(TST_BuilderInternal.globalGenerateMockIds, 'Global flag should be reset even after exception');
			}
		}
	}

	/**
	 * @description Verifies mock records can be used with QRY_Builder mocking
	 */
	@IsTest
	private static void mockRecordsShouldWorkWithQueryMocking()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, 'Mock Record')
					.withCount(3)
					.withoutInsertion(true)
					.buildList();

			QRY_Builder.setMock(Foobar__c.SObjectType, mockRecords);

			List<Foobar__c> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'Name'})
					.toList();

			Assert.areEqual(3, results.size(), 'Should return mocked records');
			Assert.areEqual('Mock Record', results[0].Name, 'Should have correct field values');
		}
	}

	/**
	 * @description Verifies that withDefaultedField accepts field names (like 'ParentId') in addition to
	 * relationship names (like 'Parent'). This enables users to use either format interchangeably for
	 * multi-level traversal like 'Account.ParentId.ParentId' instead of 'Account.Parent.ParentId'.
	 */
	@IsTest
	private static void withDefaultedFieldAcceptsFieldNamesForStandardLookups()
	{
		System.runAs(getTestAdmin())
		{
			//Build with field name path (AccountId instead of Account, ParentId instead of Parent)
			Case result = (Case)TST_Builder.of(Case.SObjectType)
					.withDefaultedField('AccountId.ParentId')
					.withoutInsertion(true)
					.build();

			//Main record should have a mock ID
			Assert.isNotNull(result.Id, 'Case should have a mock ID');

			//Account should be populated with its parent
			Assert.isNotNull(result.Account, 'Account relationship should be populated');
			Assert.isNotNull(result.Account.Id, 'Account should have a mock ID');
			Assert.isNotNull(result.Account.Parent, 'Account.Parent relationship should be populated');
			Assert.isNotNull(result.Account.Parent.Id, 'Account.Parent should have a mock ID');
		}
	}

	/**
	 * @description Verifies that withDefaultedField accepts custom field names (like 'Lookup__c') in addition to
	 * relationship names (like 'Lookup__r'). This enables users to use either format interchangeably.
	 */
	@IsTest
	private static void withDefaultedFieldAcceptsFieldNamesForCustomLookups()
	{
		System.runAs(getTestAdmin())
		{
			//Build with field name (Lookup__c instead of Lookup__r)
			Foobar__c result = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedField(SEL_Foobar.FIELD_LOOKUP) // Lookup__c
					.withoutInsertion(true)
					.build();

			//Main record should have a mock ID
			Assert.isNotNull(result.Id, 'Foobar should have a mock ID');

			//Lookup relationship should be populated
			Assert.isNotNull(result.Lookup__r, 'Lookup relationship should be populated');
			Assert.isNotNull(result.Lookup__r.Id, 'Lookup parent should have a mock ID');
			Assert.areEqual(result.Lookup__r.Id, result.Lookup__c, 'Lookup__c should reference the parent mock ID');
		}
	}

	/**
	 * @description Verifies multi-level traversal using field names for custom lookups
	 * like 'Lookup__c.Lookup__c' instead of 'Lookup__r.Lookup__r'.
	 */
	@IsTest
	private static void withDefaultedFieldAcceptsMultiLevelCustomFieldNames()
	{
		System.runAs(getTestAdmin())
		{
			//Build with multi-level field name path (Lookup__c.Lookup__c)
			Foobar__c result = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withDefaultedField(SEL_Foobar.FIELD_LOOKUP + UTIL_String.DOT + SEL_Foobar.FIELD_LOOKUP)
					.withoutInsertion(true)
					.build();

			//Main record should have a mock ID
			Assert.isNotNull(result.Id, 'Foobar should have a mock ID');

			//First level Lookup should be populated
			Assert.isNotNull(result.Lookup__r, 'Lookup relationship should be populated');
			Assert.isNotNull(result.Lookup__r.Id, 'Lookup parent should have a mock ID');

			//Second level Lookup (grandparent) should be populated
			Assert.isNotNull(result.Lookup__r.Lookup__r, 'Grandparent Lookup relationship should be populated');
			Assert.isNotNull(result.Lookup__r.Lookup__r.Id, 'Grandparent Lookup should have a mock ID');
		}
	}

	/**
	 * @description Verifies that withDefaultedField with field-name-based paths (e.g., 'AccountId.Name')
	 * correctly populates fields on nested parent records. This exercises the convertPrefixToFieldNameBased
	 * code path where field names (ending with 'Id') are preserved unchanged during prefix conversion.
	 */
	@IsTest
	private static void withDefaultedFieldUsingFieldNamePathPopulatesNestedFields()
	{
		System.runAs(getTestAdmin())
		{
			//Build using field name path (AccountId.Name instead of Account.Name)
			// This exercises convertPrefixToFieldNameBased with 'accountid.' prefix where
			// 'accountid' ends with 'Id' and should be kept unchanged
			Contact result = (Contact)TST_Builder.of(Contact.SObjectType)
					.withDefaultedField('AccountId.Name')
					.withoutInsertion(true)
					.build();

			//The nested parent should have an auto-generated name
			Assert.isNotNull(result.Account, 'Account relationship should be populated');
			Assert.isNotNull(result.Account.Name, 'Account.Name should be auto-populated via field name path');
		}
	}

	/**
	 * @description Verifies that withDefaultedField with three-level field-name-based paths
	 * (e.g., 'AccountId.ParentId.Name') correctly populates the entire hierarchy.
	 */
	@IsTest
	private static void withDefaultedFieldUsingThreeLevelFieldNamePath()
	{
		System.runAs(getTestAdmin())
		{
			//Build with three-level field name path
			// This exercises convertPrefixToFieldNameBased with prefixes like 'accountid.parentid.'
			Contact result = (Contact)TST_Builder.of(Contact.SObjectType)
					.withDefaultedField('AccountId.ParentId.Name')
					.withoutInsertion(true)
					.build();

			//All three levels should be populated
			Assert.isNotNull(result.Account, 'Account relationship should be populated');
			Assert.isNotNull(result.Account.Id, 'Account should have a mock ID');
			Assert.isNotNull(result.Account.Parent, 'Grandparent Account should be populated');
			Assert.isNotNull(result.Account.Parent.Id, 'Grandparent Account should have a mock ID');
			Assert.isNotNull(result.Account.Parent.Name, 'Grandparent Account.Name should be auto-populated');
		}
	}

	/**
	 * @description Verifies that withOverride with field-name-based paths (e.g., 'AccountId.Name')
	 * correctly sets values on nested parent records by using the alternative cache key lookup.
	 */
	@IsTest
	private static void withOverrideUsingFieldNamePathSetsNestedValue()
	{
		System.runAs(getTestAdmin())
		{
			//A specific name to set on the parent account
			String expectedParentName = 'Parent Via Field Name Path';

			//Build using field name path for override (AccountId.Name instead of Account.Name)
			Contact result = (Contact)TST_Builder.of(Contact.SObjectType)
					.withOverride('AccountId.Name', expectedParentName)
					.withoutInsertion(true)
					.build();

			//The nested parent should have the overridden name
			Assert.isNotNull(result.Account, 'Account relationship should be populated');
			Assert.areEqual(expectedParentName, result.Account.Name, 'Account.Name should be set via field name path');
		}
	}

	/**
	 * @description Verifies that combining withDefaultedField and withOverride using field-name paths
	 * works correctly for multi-level relationships.
	 */
	@IsTest
	private static void withOverrideUsingMultiLevelFieldNamePaths()
	{
		System.runAs(getTestAdmin())
		{
			//Specific values to override at different levels using field name paths
			String expectedParentName = 'Explicit Parent';
			String expectedGrandparentName = 'Explicit Grandparent';

			//Build with field name paths for overrides
			Contact result = (Contact)TST_Builder.of(Contact.SObjectType)
					.withOverride('AccountId.Name', expectedParentName)
					.withOverride('AccountId.ParentId.Name', expectedGrandparentName)
					.withoutInsertion(true)
					.build();

			//Both parent and grandparent should have correct values
			Assert.isNotNull(result.Account, 'Account relationship should be populated');
			Assert.areEqual(expectedParentName, result.Account.Name, 'Parent Account name should match override');
			Assert.isNotNull(result.Account.Parent, 'Grandparent Account should be populated');
			Assert.areEqual(expectedGrandparentName, result.Account.Parent.Name, 'Grandparent Account name should match override');
		}
	}

	/**
	 * @description Verifies that withOverride accepts an SObject value in a nested path,
	 * exercising the putSObject code path for SObject values in multi-level traversal.
	 */
	@IsTest
	private static void withOverrideAcceptsSObjectValueInNestedPath()
	{
		System.runAs(getTestAdmin())
		{
			//Create a grandparent account with a mock ID
			Account grandparentAccount = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Name, 'Grandparent Account')
					.withoutInsertion(true)
					.build();

			//Build with an SObject value in a nested path (Account.Parent = SObject)
			Contact result = (Contact)TST_Builder.of(Contact.SObjectType)
					.withOverride('Account.Parent', grandparentAccount)
					.withoutInsertion(true)
					.build();

			//The nested relationship should be set correctly
			Assert.isNotNull(result.Account, 'Account relationship should be populated');
			Assert.isNotNull(result.Account.ParentId, 'Account.ParentId should be set');
			Assert.areEqual(grandparentAccount.Id, result.Account.ParentId, 'Account.ParentId should reference the grandparent');
		}
	}

	/**
	 * @description Tests that withCycle distributes values cyclically across records using an SObjectField token.
	 */
	@IsTest
	private static void shouldCycleValuesAcrossRecordsWithSObjectField()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> cycleValues = new List<Object> {'Alpha', 'Beta', 'Gamma'};

			List<Foobar__c> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withCycle(Foobar__c.Text__c, cycleValues)
					.withCount(6)
					.withoutInsertion()
					.buildList();

			Assert.areEqual(6, foobars.size(), 'Should build 6 records');
			Assert.areEqual('Alpha', foobars[0].Text__c, 'Index 0 should be Alpha');
			Assert.areEqual('Beta', foobars[1].Text__c, 'Index 1 should be Beta');
			Assert.areEqual('Gamma', foobars[2].Text__c, 'Index 2 should be Gamma');
			Assert.areEqual('Alpha', foobars[3].Text__c, 'Index 3 should cycle back to Alpha');
			Assert.areEqual('Beta', foobars[4].Text__c, 'Index 4 should cycle back to Beta');
			Assert.areEqual('Gamma', foobars[5].Text__c, 'Index 5 should cycle back to Gamma');
		}
	}

	/**
	 * @description Tests that withCycle distributes values cyclically using a String field name.
	 */
	@IsTest
	private static void shouldCycleValuesAcrossRecordsWithString()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> cycleValues = new List<Object> {10, 20};

			List<Foobar__c> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withCycle(SEL_Foobar.FIELD_INTEGER, cycleValues)
					.withCount(4)
					.withoutInsertion()
					.buildList();

			Assert.areEqual(4, foobars.size(), 'Should build 4 records');
			Assert.areEqual(10, foobars[0].NumberInteger__c, 'Index 0 should be 10');
			Assert.areEqual(20, foobars[1].NumberInteger__c, 'Index 1 should be 20');
			Assert.areEqual(10, foobars[2].NumberInteger__c, 'Index 2 should cycle back to 10');
			Assert.areEqual(20, foobars[3].NumberInteger__c, 'Index 3 should cycle back to 20');
		}
	}

	/**
	 * @description Tests that withCycle with a single value applies it to all records.
	 */
	@IsTest
	private static void shouldCycleSingleValueToAllRecords()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withCycle(Foobar__c.Text__c, new List<Object> {'Constant'})
					.withCount(3)
					.withoutInsertion()
					.buildList();

			Assert.areEqual(3, foobars.size(), 'Should build 3 records');
			Assert.areEqual('Constant', foobars[0].Text__c, 'All records should have the same value');
			Assert.areEqual('Constant', foobars[1].Text__c, 'All records should have the same value');
			Assert.areEqual('Constant', foobars[2].Text__c, 'All records should have the same value');
		}
	}

	/**
	 * @description Tests that withCycle works alongside regular withOverride.
	 */
	@IsTest
	private static void shouldCycleCombinedWithOverrides()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withCycle(Foobar__c.Text__c, new List<Object> {'One', 'Two'})
					.withOverride(Foobar__c.NumberInteger__c, 42)
					.withCount(4)
					.withoutInsertion()
					.buildList();

			Assert.areEqual(4, foobars.size(), 'Should build 4 records');
			Assert.areEqual('One', foobars[0].Text__c, 'Cycle should apply');
			Assert.areEqual('Two', foobars[1].Text__c, 'Cycle should apply');
			Assert.areEqual('One', foobars[2].Text__c, 'Cycle should wrap');
			Assert.areEqual('Two', foobars[3].Text__c, 'Cycle should wrap');
			Assert.areEqual(42, foobars[0].NumberInteger__c, 'Static override should apply to all records');
			Assert.areEqual(42, foobars[3].NumberInteger__c, 'Static override should apply to all records');
		}
	}

	/**
	 * @description Tests that withCycle with mock IDs cycles values on in-memory records.
	 */
	@IsTest
	private static void shouldCycleValuesWithMockIds()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = TST_Builder.of(Foobar__c.SObjectType)
					.withCycle(Foobar__c.Text__c, new List<Object> {'X', 'Y'})
					.withCount(4)
					.withoutInsertion(true)
					.buildList();

			Assert.areEqual(4, foobars.size(), 'Should build 4 records');
			Assert.isNotNull(foobars[0].Id, 'Records should have mock IDs');
			Assert.areEqual('X', foobars[0].Text__c, 'Cycle should apply with mock IDs');
			Assert.areEqual('Y', foobars[1].Text__c, 'Cycle should apply with mock IDs');
			Assert.areEqual('X', foobars[2].Text__c, 'Cycle should wrap with mock IDs');
			Assert.areEqual('Y', foobars[3].Text__c, 'Cycle should wrap with mock IDs');
		}
	}

	/**
	 * @description Tests that withCycle throws an exception for a null SObjectField.
	 */
	@IsTest
	private static void shouldThrowExceptionForNullFieldInCycle()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withCycle((SObjectField)null, new List<Object> {'A'});

				Assert.fail('Should throw IllegalArgumentException for null field');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for null field');
				Assert.isTrue(error.getMessage().contains('Field cannot be null'), 'Error message should mention null field');
			}
		}
	}

	/**
	 * @description Tests that withCycle throws an exception for a blank field name.
	 */
	@IsTest
	private static void shouldThrowExceptionForBlankFieldNameInCycle()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withCycle('', new List<Object> {'A'});

				Assert.fail('Should throw IllegalArgumentException for blank field name');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for blank field name');
				Assert.isTrue(error.getMessage().contains('blank'), 'Error message should mention blank');
			}
		}
	}

	/**
	 * @description Tests that withCycle throws an exception for a null values list.
	 */
	@IsTest
	private static void shouldThrowExceptionForNullValuesInCycle()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withCycle(Foobar__c.Text__c, null);

				Assert.fail('Should throw IllegalArgumentException for null values');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for null values');
				Assert.isTrue(error.getMessage().contains('null or empty'), 'Error message should mention null or empty');
			}
		}
	}

	/**
	 * @description Tests that withCycle throws an exception for an empty values list.
	 */
	@IsTest
	private static void shouldThrowExceptionForEmptyValuesInCycle()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withCycle(Foobar__c.Text__c, new List<Object>());

				Assert.fail('Should throw IllegalArgumentException for empty values');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for empty values');
				Assert.isTrue(error.getMessage().contains('null or empty'), 'Error message should mention null or empty');
			}
		}
	}

	/**
	 * @description Tests that withCycle String overload throws an exception for an empty values list.
	 */
	@IsTest
	private static void shouldThrowExceptionForEmptyValuesInCycleByFieldName()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				TST_Builder.of(Foobar__c.SObjectType)
						.withCycle(SEL_Foobar.FIELD_TEXT, new List<Object>());

				Assert.fail('Should throw IllegalArgumentException for empty values');
			}
			catch(Exception error)
			{
				assertIsIllegalArgumentException(error, 'Should throw IllegalArgumentException for empty values');
				Assert.isTrue(error.getMessage().contains('null or empty'), 'Error message should mention null or empty');
			}
		}
	}

	/**
	 * @description Checks that the error is a TypeException
	 *
	 * @param error The error object to check
	 * @param assertMessage The message to display if exception is of a different type
	 *
	 * @see TypeException
	 */
	private static void assertIsTypeException(Exception error, String assertMessage)
	{
		Assert.isInstanceOfType(error, TypeException.class, assertMessage);
	}

	/**
	 * @description Checks that the error is a SObjectException
	 *
	 * @param error The error object to check
	 * @param assertMessage The message to display if exception is of a different type
	 */
	private static void assertIsObjectException(Exception error, String assertMessage)
	{
		Assert.isInstanceOfType(error, SObjectException.class, assertMessage);
	}

	/**
	 * @description Checks that the error is a DmlException
	 *
	 * @param error The error object to check
	 * @param assertMessage The message to display if exception is of a different type
	 *
	 * @see DmlException
	 */
	private static void assertIsDmlException(Exception error, String assertMessage)
	{
		Assert.isInstanceOfType(error, DmlException.class, assertMessage);
	}

	/**
	 * @description Checks that the error is an IllegalArgumentException
	 *
	 * @param error The error object to check
	 * @param assertMessage The message to display if exception is of a different type
	 *
	 * @see IllegalArgumentException
	 */
	private static void assertIsIllegalArgumentException(Exception error, String assertMessage)
	{
		Assert.isInstanceOfType(error, IllegalArgumentException.class, assertMessage);
	}

	/**
	 * @description Creates a default field list containing Name and Text.
	 *
	 * @return A List<Object> for auto-defaulting.
	 */
	private static List<Object> createDefaultListWithNameAndText()
	{
		return new List<Object>
		{
				SEL_Foobar.FIELD_NAME,
				SEL_Foobar.FIELD_TEXT
		};
	}

	/**
	 * @description Creates a default field list containing just Text.
	 *
	 * @return A List<Object> for auto-defaulting.
	 */
	private static List<Object> createDefaultListWithText()
	{
		return new List<Object> {SEL_Foobar.FIELD_TEXT};
	}

	/**
	 * @description Formats an error message string with specified values and an optional original error message.
	 *
	 * @param message The error message template.
	 * @param mergeValues The values to be merged into the error message.
	 * @param originalMessage The original error message from a caught exception.
	 *
	 * @return The formatted error message.
	 */
	private static String formatErrorMessage(String message, List<String> mergeValues, String originalMessage)
	{
		String errorMessage = String.format(message, mergeValues);
		if(String.isNotBlank(originalMessage))
		{
			errorMessage += '\n' + 'Original error message : ' + originalMessage;
		}
		return errorMessage;
	}

	/**
	 * @description Mock factory provider that only implements base interface (not extended interface).
	 */
	private class LegacyFactoryProvider implements TST_Builder.FactoryProvider
	{
		public TST_Builder.Factory createFactory(SObjectType objectType)
		{
			return new LegacyFactory(objectType);
		}
	}

	/**
	 * @description Mock factory that only implements base interface.
	 */
	private class LegacyFactory implements TST_Builder.Factory
	{
		private final SObjectType sObjectType;

		public LegacyFactory(SObjectType sObjectType)
		{
			this.sObjectType = sObjectType;
		}

		public TST_Builder.Manager getSObjectManager()
		{
			return null;
		}

		public SObject getSObjectInstance(Map<String, Object> mapOfValuesOverride, Boolean doInsert)
		{
			return sObjectType.newSObject();
		}

		public List<SObject> getListSObjectInstance(Map<String, Object> mapOfValuesOverride, Boolean doInsert, Integer numberOfSObjects)
		{
			List<SObject> results = new List<SObject>();
			for(Integer i = 0; i < numberOfSObjects; i++)
			{
				results.add(sObjectType.newSObject());
			}
			return results;
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}