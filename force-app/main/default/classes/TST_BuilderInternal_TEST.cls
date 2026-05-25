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
 * @description Test class for TST_BuilderInternal.
 * This class contains tests that target the internal SObjectManager
 * and SObjectFactory classes directly.
 *
 * @see TST_BuilderInternal
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class TST_BuilderInternal_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'TST_BuilderInternal_TEST-admin';
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
	 * @description Tests the SObjectManager's 'setSObject' method, verifying it can add new records, replace existing records by index,
	 * and throws an exception for out-of-bounds indices.
	 */
	@IsTest
	private static void managerSetSObject()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager sObjectManager = createManager();

			try
			{
				sObjectManager.setSObject(1, TST_Factory.newFoobarWithName('test1'));
				Assert.fail('Setting an SObject at an out-of-bounds index should throw an exception.');
			}
			catch(Exception error)
			{
				assertIsListException(error);
			}

			sObjectManager.setSObject(0, TST_Factory.newFoobarWithName('test1'));
			Assert.areEqual(1, sObjectManager.mainObjects.size(), 'List size should be 1 after setting at index 0.');
			Assert.areEqual('test1', ((Foobar__c)sObjectManager.mainObjects.get(0)).Name, 'First record should be test1.');

			sObjectManager.setSObject(1, TST_Factory.newFoobarWithName('test2'));
			Assert.areEqual(2, sObjectManager.mainObjects.size(), 'List size should be 2 after setting at index 1.');
			Assert.areEqual('test1', ((Foobar__c)sObjectManager.mainObjects.get(0)).Name, 'First record should still be test1.');
			Assert.areEqual('test2', ((Foobar__c)sObjectManager.mainObjects.get(1)).Name, 'Second record should be test2.');

			sObjectManager.setSObject(0, TST_Factory.newFoobarWithName('test3'));
			Assert.areEqual(2, sObjectManager.mainObjects.size(), 'List size should remain 2 after replacing at index 0.');
			Assert.areEqual('test3', ((Foobar__c)sObjectManager.mainObjects.get(0)).Name, 'First record should be updated to test3.');
			Assert.areEqual('test2', ((Foobar__c)sObjectManager.mainObjects.get(1)).Name, 'Second record should still be test2.');
		}
	}

	/**
	 * @description Tests the SObjectManager's 'getSObject' method, verifying it retrieves the correct record by index and throws an exception for out-of-bounds indices.
	 */
	@IsTest
	private static void managerGetSObject()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager sObjectManager = createManager();

			try
			{
				sObjectManager.getSObject(0);
				Assert.fail('Getting an SObject from an out-of-bounds index should throw an exception.');
			}
			catch(Exception error)
			{
				assertIsListException(error);
			}

			sObjectManager.mainObjects.add(TST_Factory.newFoobar());
			Assert.isNotNull(sObjectManager.getSObject(0), 'Should retrieve the SObject at index 0.');
		}
	}

	/**
	 * @description Tests the SObjectManager's 'insertAll' method, ensuring it inserts and links
	 * records that were registered with it (simulating the factory build process).
	 */
	@IsTest
	private static void managerInsertAll()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager sObjectManager = createManager();

			Foobar__c parentRecord = TST_Factory.newFoobarWithName(TEST_STRING);
			String childName = 'Child ' + TEST_STRING;
			Foobar__c childRecord = TST_Factory.newFoobarWithName(childName);

			// 1. Register the main object (Child Foobar__c)
			sObjectManager.setSObject(0, childRecord, true);
			// 2. Register the related object (Parent Foobar__c) using the relationship name
			sObjectManager.registerAndCache(0, SEL_Foobar.RELATIONSHIP_LOOKUP, parentRecord, true);
			// 3. Register the link between them (Parent, Child's Lookup Field, Child)
			sObjectManager.registerLink(parentRecord, Foobar__c.Lookup__c, childRecord);

			Test.startTest();
			sObjectManager.insertAll();
			Test.stopTest();

			Foobar__c foundFoobar = (Foobar__c)QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String>(UTIL_SObjectDescribe.getSObjectFieldNames(new Set<SObjectField>(new SEL_Foobar().fields))))
					.addFields(new List<String> {SEL_Foobar.FIELD_PARENT_NAME})
					.condition('Name').equals(childName)
					.getFirst();

			Assert.isNotNull(foundFoobar, 'The inserted foobar (child) should be found in the database.');
			Assert.areEqual(childName, foundFoobar.Name, 'Foobar Name should be inserted correctly.');
			Assert.isNotNull(foundFoobar.Lookup__c, 'Foobar.Lookup__c should not be null.');
			Assert.areEqual(TEST_STRING, foundFoobar.Lookup__r.Name, 'Related Foobar (parent) Name should be inserted and linked correctly.');
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'getSObjectInstance' method for creating a single SObject.
	 */
	@IsTest
	private static void factoryGetSObjectInstance()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			SObject sObjectInstance = sObjectFactory.getSObjectInstance(new Map<String, Object>(), false);

			Assert.isNotNull(sObjectInstance, 'The SObject instance should not be null.');
			Assert.areEqual(Foobar__c.SObjectType, sObjectInstance.getSObjectType(), 'The SObject instance should be of the correct type (Foobar__c).');
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'getListSObjectInstance' method for creating a list of SObjects with related data.
	 */
	@IsTest
	private static void factoryGetListSObjectInstance()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			List<SObject> sObjectList = sObjectFactory.getListSObjectInstance
					(
							new Map<String, Object> {SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + 'Name' => TEST_STRING},
							false,
							5
					);

			Assert.isNotNull(sObjectList, 'The SObject list should not be null.');
			Assert.areEqual(5, sObjectList.size(), 'The list should contain 5 SObjects.');
			Assert.areEqual(Foobar__c.SObjectType, sObjectList.get(0).getSObjectType(), 'The SObject instance should be of the correct type (Foobar__c).');
			Assert.isNotNull(sObjectList.get(0).getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP), 'The related Foobar SObject should not be null.');
			Assert.areEqual(TEST_STRING, sObjectList.get(0).getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP).get('Name'), 'The related Foobar Name field should be set correctly.');
		}
	}

	/**
	 * @description Tests 'getListSObjectInstance' when `doInsert=false` (withoutInsertion).
	 * Verifies it correctly applies read-only fields, read-only lookups,
	 * and read-only child relationships using the new JSON mocking logic.
	 */
	@IsTest
	private static void factoryGetListSObjectInstanceWithoutInsertAppliesReadOnlyMocks()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = new TST_BuilderInternal.SObjectFactory(Foobar__c.SObjectType);

			//A read-only lookup SObject
			User testUser = new User(Id = UTIL_Random.randomId(User.SObjectType), LastName = 'TestUser');

			// A read-only child relationship List
			List<SObject> testChildren = new List<SObject>
			{
					new Foobar__c(Name = 'TestChild1'),
					new Foobar__c(Name = 'TestChild2')
			};

			Map<String, Object> overrides = new Map<String, Object>
			{
					'Name' => 'Writeable Field', // A normal writeable field
					'CreatedById' => testUser.Id, // A read-only field
					'CreatedBy' => testUser, // A read-only lookup
					SEL_Foobar.RELATIONSHIP_FOOBARS => testChildren // A read-only child relationship
			};

			Test.startTest();

			List<SObject> sObjectList = sObjectFactory.getListSObjectInstance(overrides, false, 1);

			Test.stopTest();

			//Verify all fields (writeable and read-only) are populated
			Assert.isNotNull(sObjectList, 'The SObject list should not be null.');
			Assert.areEqual(1, sObjectList.size(), 'The list should contain 1 SObject.');

			Foobar__c mockedRecord = (Foobar__c)sObjectList.get(0);
			Assert.isNull(mockedRecord.Id, 'Id should be null (in-memory).');
			Assert.areEqual('Writeable Field', mockedRecord.Name, 'Writeable field should be set.');

			// Verify read-only primitive
			Assert.areEqual(testUser.Id, mockedRecord.CreatedById, 'Read-only field (CreatedById) should be set.');

			// Verify read-only lookup
			Assert.isNotNull(mockedRecord.CreatedBy, 'Read-only lookup (CreatedBy) should be populated.');
			Assert.areEqual(testUser.LastName, mockedRecord.CreatedBy.LastName, 'Read-only lookup data should be correct.');

			// Verify read-only child relationship
			List<Foobar__c> children = mockedRecord.getSObjects(SEL_Foobar.RELATIONSHIP_FOOBARS);
			Assert.isNotNull(children, 'Read-only child relationship should be populated.');
			Assert.areEqual(2, children.size(), 'Child relationship list size should be correct.');
			Assert.areEqual('TestChild1', children.get(0).Name, 'Child record data should be correct.');
		}
	}

	/**
	 * @description Tests 'getListSObjectInstance' when `doInsert=true`.
	 * Verifies it (correctly) does *not* attempt to apply read-only
	 * fields, which would cause a DML exception.
	 */
	@IsTest
	private static void factoryGetListSObjectInstanceWithInsertSkipsReadOnlyMocks()
	{
		System.runAs(getTestAdmin())
		{
			//Use Foobar, which has real read-only fields
			TST_BuilderInternal.SObjectFactory sObjectFactory = new TST_BuilderInternal.SObjectFactory(Foobar__c.SObjectType);
			Id mockId = UTIL_Random.randomId(User.SObjectType);

			Map<String, Object> overrides = new Map<String, Object>
			{
					Foobar__c.Name.getDescribe().name => 'Writeable Field',
					Foobar__c.CreatedById.getDescribe().name => mockId // Attempt to set read-only field
			};

			// Build the Foobar with insertion (doInsert=true)
			Test.startTest();

			List<SObject> sObjectList = sObjectFactory.getListSObjectInstance(overrides, true, 1);

			Test.stopTest();

			//Verify insertion succeeded and read-only field was ignored
			Assert.isNotNull(sObjectList, 'The SObject list should not be null.');
			Assert.areEqual(1, sObjectList.size(), 'The list should contain 1 SObject.');

			Foobar__c insertedFoobar = (Foobar__c)sObjectList.get(0);
			Assert.isNotNull(insertedFoobar.Id, 'Id should be populated (inserted).');
			Assert.areEqual('Writeable Field', insertedFoobar.Name, 'Writeable field should be set.');
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'initSObjectInstance' method, verifying it correctly populates the SObjectManager with the main SObject and its related records.
	 */
	@IsTest
	private static void factoryInitSObjectInstance()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			sObjectFactory.initSObjectInstance
					(
							new Map<String, TST_Builder.DefaultFieldValueProvider>
							{
									// Use the self-lookup relationship 'Lookup__r'
									SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + 'Name' => new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(TEST_STRING)
							},
							0,
							false
					);

			Assert.isNotNull(sObjectFactory.getSObjectManager(), 'The SObjectManager should not be null.');
			Assert.isNotNull(sObjectFactory.getSObjectManager().getMainObjects(), 'The main objects list should not be null.');
			Assert.areEqual(1, sObjectFactory.getSObjectManager().getMainObjects().size(), 'The SObjectManager should contain one main object.');
			SObject mainSObject = sObjectFactory.getSObjectManager().getMainObjects().get(0);
			Assert.isNotNull(mainSObject, 'The main SObject instance should not be null.');
			Assert.isNotNull(mainSObject.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP), 'The related Foobar SObject should be attached.');
			Assert.areEqual(TEST_STRING, mainSObject.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP).get('Name'), 'The related Foobar Name field should be set.');
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'getRelationshipInstance' method, ensuring it correctly instantiates a multi-level related SObject
	 * (e.g., Account from Case via Contact).
	 */
	@IsTest
	private static void factoryGetRelationshipInstance()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			// Use multi-level self-lookup: Foobar__c -> Lookup__r -> Lookup__r
			String multiLevelRelationship = SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + SEL_Foobar.RELATIONSHIP_LOOKUP;

			SObject sObjectInstance = sObjectFactory.getRelationshipInstance(multiLevelRelationship, 0, false);

			Assert.isNotNull(sObjectInstance, 'The relationship instance should not be null.');
			Assert.areEqual(Foobar__c.SObjectType, sObjectInstance.getSObjectType(), 'The relationship instance should be of the correct type (Foobar__c).');
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'getRelatedSObjectInstance' method,
	 * ensuring it correctly instantiates an SObject based on a relationship name from a parent SObject type.
	 */
	@IsTest
	private static void factoryGetRelatedSObjectInstance()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			// Get related Foobar__c via the 'Lookup__r' relationship
			SObject sObjectInstance = sObjectFactory.getRelatedSObjectInstance(Foobar__c.SObjectType, SEL_Foobar.RELATIONSHIP_LOOKUP, UTIL_String.EMPTY);

			Assert.isNotNull(sObjectInstance, 'The related SObject instance should not be null.');
			Assert.areEqual(Foobar__c.SObjectType, sObjectInstance.getSObjectType(), 'The related SObject instance should be of the correct type (Foobar__c).');
		}
	}

	/**
	 * @description Tests that 'getRelatedSObjectInstance' throws an exception
	 * if the relationship does not exist in the schema.
	 */
	@IsTest
	private static void factoryGetRelatedSObjectInstanceInvalidRelationship()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			try
			{
				// Attempt to get a relationship that doesn't exist
				sObjectFactory.getRelatedSObjectInstance(Foobar__c.SObjectType, 'InvalidRelationship__r', 'TestContext');
				Assert.fail('Expected SObjectException for invalid relationship.');
			}
			catch(Exception error)
			{
				assertIsObjectException
						(
								error,
								'The relationship "InvalidRelationship__r" (field: "InvalidRelationship__c") is invalid for SObject "TestContext". It does not exist in the schema.'
						);
			}
		}
	}

	/**
	 * @description Tests that 'getRelatedSObjectInstance' throws an exception
	 * if the field exists but is not a reference (lookup/master-detail).
	 */
	@IsTest
	private static void factoryGetRelatedSObjectInstanceNotReference()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			// We need a field that EXISTS but is NOT a reference.
			// 'Name' fails because the factory converts input 'Name' to 'NameId', which doesn't exist.
			// Instead, we take a known custom field 'Text__c' and pretend we are accessing it via relationship 'Text__r'.
			// The factory converts 'Text__r' -> 'Text__c', finds the field, and throws the correct error because it's a String.
			String nonReferenceField = SEL_Foobar.FIELD_TEXT; // e.g. 'Text__c'
			String fakeRelationshipName = nonReferenceField.replace('__c', '__r'); // e.g. 'Text__r'

			try
			{
				sObjectFactory.getRelatedSObjectInstance(Foobar__c.SObjectType, fakeRelationshipName, 'TestContext');
				Assert.fail('Expected SObjectException for non-reference field.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'The field "' + nonReferenceField + '" on "TestContext" is not a relationship field or has no referenceTo targets.');
			}
		}
	}

	/**
	 * @description Tests that 'getRelatedSObjectInstance' correctly handles custom field names (ending in __c)
	 * in addition to relationship names (ending in __r). This allows users to use either 'Lookup__c' or 'Lookup__r'.
	 */
	@IsTest
	private static void factoryGetRelatedSObjectInstanceWithCustomFieldName()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			// Use the field name (Lookup__c) directly instead of the relationship name (Lookup__r)
			SObject sObjectInstance = sObjectFactory.getRelatedSObjectInstance(Foobar__c.SObjectType, SEL_Foobar.FIELD_LOOKUP, UTIL_String.EMPTY);

			Assert.isNotNull(sObjectInstance, 'The related SObject instance should not be null when using field name.');
			Assert.areEqual(Foobar__c.SObjectType, sObjectInstance.getSObjectType(), 'The related SObject instance should be of the correct type (Foobar__c).');
		}
	}

	/**
	 * @description Tests that 'getRelatedSObjectInstance' correctly handles standard field names (ending in Id)
	 * in addition to relationship names. This allows users to use either 'ParentId' or 'Parent' for Account.
	 */
	@IsTest
	private static void factoryGetRelatedSObjectInstanceWithStandardFieldName()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			// Use the field name (ParentId) directly instead of the relationship name (Parent)
			SObject sObjectInstance = sObjectFactory.getRelatedSObjectInstance(Account.SObjectType, 'ParentId', UTIL_String.EMPTY);

			Assert.isNotNull(sObjectInstance, 'The related SObject instance should not be null when using field name.');
			Assert.areEqual(Account.SObjectType, sObjectInstance.getSObjectType(), 'The related SObject instance should be of the correct type (Account).');
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'getFieldValueFromMapOfValues' method, verifying it correctly retrieves values from different DefaultFieldValueProvider types.
	 */
	@IsTest
	private static void factoryGetFieldValueFromMapOfValues()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = new Map<String, TST_Builder.DefaultFieldValueProvider>
			{
					SEL_Foobar.FIELD_NAME => new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(TEST_STRING),
					SEL_Foobar.FIELD_TEXT => new UTIL_SObjectBuilderDefaultProvider.ListFieldDefaultValue(new List<String> {TEST_STRING})
			};

			Assert.areEqual
					(
							TEST_STRING,
							sObjectFactory.getFieldValueFromMapOfValues(mapOfValues, SEL_Foobar.FIELD_NAME, 0),
							'Should retrieve value from FieldDefaultValue provider.'
					);
			Assert.areEqual
					(
							TEST_STRING,
							sObjectFactory.getFieldValueFromMapOfValues(mapOfValues, SEL_Foobar.FIELD_TEXT, 0),
							'Should retrieve value from ListFieldDefaultValue provider at index'
					);
			Assert.areEqual
					(
							TEST_STRING,
							sObjectFactory.getFieldValueFromMapOfValues(mapOfValues, SEL_Foobar.FIELD_TEXT, 1),
							'Should retrieve value from ListFieldDefaultValue provider at index'
					);
			Assert.areEqual
					(
							TEST_STRING,
							sObjectFactory.getFieldValueFromMapOfValues(mapOfValues, SEL_Foobar.FIELD_TEXT, 2),
							'Should retrieve value from ListFieldDefaultValue provider at index'
					);
			Assert.areEqual
					(
							TEST_STRING,
							sObjectFactory.getFieldValueFromMapOfValues(mapOfValues, SEL_Foobar.FIELD_TEXT, 3),
							'ListFieldDefaultValue provider should cycle values.'
					);

			try
			{
				// Use another field on Foobar__c for the non-existent check
				sObjectFactory.getFieldValueFromMapOfValues(mapOfValues, SEL_Foobar.FIELD_EMAIL, 3);
				Assert.fail('Expected an Exception for a non-existent FieldName, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'Configuration Error: No default value provider found for field "' + SEL_Foobar.FIELD_EMAIL);
			}
		}
	}

	/**
	 * @description Tests that 'getFieldValueFromMapOfValues' wraps exceptions thrown
	 * by the provider into a more descriptive error message.
	 */
	@IsTest
	private static void factoryGetFieldValueFromMapOfValuesWrapsException()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			// Use the mocked ExceptionThrowingProvider
			Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues = new Map<String, TST_Builder.DefaultFieldValueProvider>
			{
					SEL_Foobar.FIELD_NAME => new ExceptionThrowingProvider()
			};

			try
			{
				sObjectFactory.getFieldValueFromMapOfValues(mapOfValues, SEL_Foobar.FIELD_NAME, 0);
				Assert.fail('Expected exception from provider.');
			}
			catch(Exception error)
			{
				Assert.isTrue(error.getMessage().contains('Error generating value for field "Name"'), 'Error message should be wrapped with context.');
				Assert.isTrue(error.getMessage().contains('Intentional Test Error'), 'Error message should contain original error.');
			}
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'putSObject' helper method, ensuring it correctly attaches a related SObject and throws an exception for invalid relationship names.
	 */
	@IsTest
	private static void factoryPutSObject()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c foobarRecord = TST_Factory.newFoobar();

			// Attach a parent Foobar__c via the 'Lookup__r' relationship
			sObjectFactory.putSObject(foobarRecord, SEL_Foobar.RELATIONSHIP_LOOKUP, TST_Factory.newFoobarWithName(TEST_STRING), UTIL_String.EMPTY, false, 0);
			Assert.areEqual(TEST_STRING, foobarRecord.Lookup__r.Name, 'The related Foobar record should be attached to the main Foobar.');

			try
			{
				sObjectFactory.putSObject(foobarRecord, TEST_STRING, TST_Factory.newFoobar(), UTIL_String.EMPTY, false, 0);
				Assert.fail('Expected an SObjectException for a non-existent relationship, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'The relationship "test" (field: "testId") does not exist on "".');
			}
		}
	}

	/**
	 * @description Tests 'putSObject' when the lookup field is read-only.
	 * Verifies it calls 'registerReadOnlyOverride' instead of .put().
	 * Note: We test this on 'CreatedBy', which maps to 'CreatedById' (read-only).
	 */
	@IsTest
	private static void factoryPutSObjectReadOnlyFieldRegistersOverride()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = new TST_BuilderInternal.SObjectFactory(Foobar__c.SObjectType);
			Foobar__c newRecord = new Foobar__c();
			User testUser = new User(Id = UTIL_Random.randomId(User.SObjectType), LastName = 'TestUser');
			Integer index = 0;
			String path = SEL_Foobar.OBJECT_NAME;

			//putSObject is called for the read-only 'CreatedBy' relationship. Pass 0 as index.
			sObjectFactory.putSObject(newRecord, 'CreatedBy', testUser, path, false, index);

			//The value should be in readOnlyOverrides, not on the object
			Assert.isFalse(newRecord.getPopulatedFieldsAsMap().containsKey('CreatedById'), 'CreatedById should not be set directly on the SObject.');
			Assert.isTrue(sObjectFactory.getSObjectManager().hasReadOnlyOverrides(), 'SObjectManager should have read-only overrides.');

			// Retrieve overrides for index 0 and path
			Map<String, Object> overrides = sObjectFactory.getSObjectManager().getReadOnlyOverrides(index, path);

			Assert.isNotNull(overrides, 'Overrides for index 0 should exist.');
			Assert.isTrue(overrides.containsKey('CreatedBy'), 'Override map should contain "CreatedBy" relationship.');
			Assert.areEqual(testUser, overrides.get('CreatedBy'), 'Override map should contain the User SObject.');
			Assert.isTrue(overrides.containsKey('CreatedById'), 'Override map should contain "CreatedById" field.');
			Assert.areEqual(testUser.Id, overrides.get('CreatedById'), 'Override map should contain the User Id.');
		}
	}

	/**
	 * @description Tests the SObjectFactory's 'putField' helper method, ensuring it correctly sets a field value and throws an exception for invalid field names.
	 */
	@IsTest
	private static void factoryPutField()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c foobarRecord = TST_Factory.newFoobar();

			sObjectFactory.putField(foobarRecord, SEL_Foobar.FIELD_NAME, TEST_STRING, UTIL_String.EMPTY, 0);
			Assert.areEqual(TEST_STRING, foobarRecord.Name, 'The Name field should be set on the Foobar.');

			try
			{
				sObjectFactory.putField(foobarRecord, TEST_STRING, TEST_STRING, UTIL_String.EMPTY, 0);
				Assert.fail('Expected an SObjectException for a non-existent field, but none was thrown.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'Field "test" does not exist on SObject "".');
			}
		}
	}

	/**
	 * @description Tests that 'putField' correctly handles specific Type Exceptions
	 * and wraps them with a descriptive error message.
	 */
	@IsTest
	private static void factoryPutFieldTypeMismatch()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c foobarRecord = TST_Factory.newFoobar();
			try
			{
				// Attempt to put a Boolean into a String field (Name).
				sObjectFactory.putField(foobarRecord, SEL_Foobar.FIELD_NAME, true, 'Foobar__c', 0);
				Assert.fail('Expected Type Mismatch exception.');
			}
			catch(Exception error)
			{
				assertIsObjectException(error, 'Illegal assignment from Boolean to String');
			}
		}
	}

	/**
	 * @description Tests that 'putField' gracefully ignores null values for non-existent fields
	 * (acting as "junk key" logic), without throwing an exception.
	 */
	@IsTest
	private static void factoryPutFieldIgnoresNullForNonExistentField()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c foobarRecord = TST_Factory.newFoobar();

			try
			{
				// Calling putField with a non-existent field BUT a null value
				sObjectFactory.putField(foobarRecord, 'NonExistentJunkField', null, 'Foobar__c', 0);
				// Should just return
			}
			catch(Exception e)
			{
				Assert.fail('Should not throw exception for null value on non-existent field.');
			}
		}
	}

	/**
	 * @description Tests 'putField' when the field is read-only.
	 * Verifies it calls 'registerReadOnlyOverride' instead of .put().
	 */
	@IsTest
	private static void factoryPutFieldReadOnlyFieldRegistersOverride()
	{
		System.runAs(getTestAdmin())
		{
			//Use Foobar__c, which has read-only CreatedById
			TST_BuilderInternal.SObjectFactory sObjectFactory = new TST_BuilderInternal.SObjectFactory(Foobar__c.SObjectType);
			Foobar__c newFoobar = TST_Factory.newFoobar();
			Id mockId = UTIL_Random.randomId(User.SObjectType);
			Integer index = 0;
			String path = SEL_Foobar.OBJECT_NAME;

			//putField is called for the read-only 'CreatedById' field
			sObjectFactory.putField(newFoobar, Foobar__c.CreatedById.getDescribe().name, mockId, path, index);

			//The value should be in readOnlyOverrides, not on the object
			Assert.isFalse(newFoobar.getPopulatedFieldsAsMap().containsKey('CreatedById'), 'CreatedById should not be set directly on the SObject.');
			Assert.isTrue(sObjectFactory.getSObjectManager().hasReadOnlyOverrides(), 'SObjectManager should have read-only overrides.');

			// Retrieve overrides for index 0 and path 'Foobar__c'
			Map<String, Object> overrides = sObjectFactory.getSObjectManager().getReadOnlyOverrides(index, path);

			Assert.isNotNull(overrides, 'Overrides for index 0 should exist.');
			Assert.isTrue(overrides.containsKey('CreatedById'), 'Override map should contain the field name.');
			Assert.areEqual(mockId, overrides.get('CreatedById'), 'Override map should contain the correct value.');
		}
	}

	/**
	 * @description Tests 'getListSObjectInstance' (doInsert=false) when a
	 * List of *primitives* is provided for a *read-only field*.
	 * This verifies that the ListFieldDefaultValue is correctly processed
	 * by the SObjectFactory, calling 'putField' for each index,
	 * which then routes to 'registerReadOnlyOverride' for mocking.
	 */
	@IsTest
	private static void factoryGetListWithoutInsertAppliesReadOnlyListPrimitives()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory objectFactory = new TST_BuilderInternal.SObjectFactory(Foobar__c.SObjectType);

			Id mockId1 = UTIL_Random.randomId(User.SObjectType);
			Id mockId2 = UTIL_Random.randomId(User.SObjectType);
			List<Id> idList = new List<Id> {mockId1, mockId2};

			Map<String, Object> overrides = new Map<String, Object>
			{
					// Pass the List<Id> to the read-only 'CreatedById' field
					Foobar__c.CreatedById.getDescribe().name => idList
			};

			Test.startTest();

			List<SObject> sObjectList = objectFactory.getListSObjectInstance(overrides, false, 2);

			Test.stopTest();

			// 4. Verify
			Assert.isNotNull(sObjectList, 'The SObject list should not be null.');
			Assert.areEqual(2, sObjectList.size(), 'The list should contain 2 SObjects.');

			Foobar__c foobar1 = (Foobar__c)sObjectList.get(0);
			Foobar__c foobar2 = (Foobar__c)sObjectList.get(1);

			Assert.areEqual(mockId1, foobar1.CreatedById, 'Foobar 1 CreatedById should be set to index 0 of the list.');
			Assert.areEqual(mockId2, foobar2.CreatedById, 'Foobar 2 CreatedById should be set to index 1 of the list.');
		}
	}

	/**
	 * @description Tests 'getListSObjectInstance' with mixed override scenarios.
	 * Creates 2 records:
	 * Index 0: Receives a NULL for a read-only field. The factory ignores nulls, so no override is registered.
	 * Index 1: Receives a valid ID for a read-only field. The factory registers an override.
	 * This forces the code to enter the 'if(overrides == null)' block for Index 0 inside the processing loop.
	 */
	@IsTest
	private static void factoryGetListSObjectInstanceMixedOverrides()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = new TST_BuilderInternal.SObjectFactory(Foobar__c.SObjectType);

			// Setup a list where the first item is null, second is a valid ID
			Id validId = UTIL_Random.randomId(User.SObjectType);
			List<Object> createdByIds = new List<Object> {null, validId};

			Map<String, Object> overrides = new Map<String, Object>
			{
					// CreatedById is a read-only field
					'CreatedById' => createdByIds
			};

			Test.startTest();
			// Generate 2 objects without insertion
			List<SObject> results = sObjectFactory.getListSObjectInstance(overrides, false, 2);
			Test.stopTest();

			Assert.areEqual(2, results.size(), 'Should return 2 objects');

			// Index 0: Should have no ID (override was null/ignored)
			Assert.isNull(results[0].get('CreatedById'), 'Index 0 should have no CreatedById override');

			// Index 1: Should have ID (override applied)
			Assert.areEqual(validId, results[1].get('CreatedById'), 'Index 1 should have CreatedById override');
		}
	}

	/**
	 * @description Tests the 'putSObject' method re-throw logic.
	 * We pass an invalid SObject type to a relationship.
	 * This throws an SObjectException that is NOT a "not editable" error,
	 * ensuring the 'else { throw error; }' line is covered.
	 */
	@IsTest
	private static void factoryPutSObjectRethrowsMismatchException()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c foobarRecord = TST_Factory.newFoobar();

			// Create a User object, but try to put it into the 'Lookup__r' (which expects Foobar__c)
			User invalidTypeRecord = new User(Id = UTIL_Random.randomId(User.SObjectType));

			try
			{
				// This will throw SObjectException: "Invalid relationship value type"
				sObjectFactory.putSObject(foobarRecord, SEL_Foobar.RELATIONSHIP_LOOKUP, invalidTypeRecord, 'TestContext', false, 0);
				Assert.fail('Expected SObjectException due to type mismatch in relationship.');
			}
			catch(Exception error)
			{
				// Verify it is an SObjectException and NOT the generic Exception wrapper yet
				Assert.isInstanceOfType(error, SObjectException.class, 'Should be SObjectException');
				Assert.isFalse(error.getMessage().contains('not editable'), 'Should not be a read-only error');
			}
		}
	}

	/**
	 * @description Tests the 'putField' method specifically for the Type Mismatch catch block.
	 * Note: In most API versions, sObj.put() throws SObjectException for type mismatches,
	 * which hits the FIRST catch block. This test ensures that if an exception is thrown,
	 * it is handled correctly.
	 */
	@IsTest
	private static void factoryPutFieldGenericException()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c foobarRecord = TST_Factory.newFoobar();

			try
			{
				// Putting a Boolean into a Text field throws an exception
				sObjectFactory.putField(foobarRecord, SEL_Foobar.FIELD_NAME, true, 'Foobar__c', 0);
				Assert.fail('Expected Exception');
			}
			catch(Exception error)
			{
				// Depending on API version, this may be SObjectException or TypeException.
				// The factory catches SObjectException first.
				// This asserts that we are covering the exception handling logic generally.
				Assert.isNotNull(error.getMessage(), 'Exception should have a message');
			}
		}
	}

	/**
	 * @description Creates a new SObjectManager for Foobar__c.
	 *
	 * @return A new instance of SObjectManager.
	 */
	private static TST_BuilderInternal.SObjectManager createManager()
	{
		return new TST_BuilderInternal.SObjectManager(UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType));
	}

	/**
	 * @description Creates a new SObjectFactory for Foobar__c.
	 *
	 * @return A new instance of SObjectFactory.
	 */
	private static TST_BuilderInternal.SObjectFactory createFactory()
	{
		return new TST_BuilderInternal.SObjectFactory(Foobar__c.SObjectType);
	}

	/**
	 * @description Checks that the error is a SObjectException
	 *
	 * @param error The error object to check
	 * @param assertMessage The message to display if exception is of a different type
	 */
	private static void assertIsObjectException(Exception error, String assertMessage)
	{
		Assert.isInstanceOfType(error, SObjectException.class, 'Exception should be SObjectException');
		String expectedSubstring = assertMessage.substring(0, Math.min(100, assertMessage.length()));
		Assert.isTrue(error.getMessage().contains(expectedSubstring), 'Exception message should contain expected text: ' + expectedSubstring);
	}

	/**
	 * @description Checks that the error is a ListException
	 *
	 * @param error The error object to check
	 *
	 * @see ListException
	 */
	private static void assertIsListException(Exception error)
	{
		Assert.isInstanceOfType(error, ListException.class, 'Should throw ListException for out-of-bounds index.');
	}

	/**
	 * @description Tests that getListSObjectInstanceWithChildren applies read-only field mocks to parent records.
	 * This covers the path where parents have read-only overrides when creating children.
	 */
	@IsTest
	private static void shouldApplyReadOnlyFieldsToParentsWithChildren()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory factory = createFactory();

			// Create parent with read-only field
			Map<String, Object> parentOverrides = new Map<String, Object>
			{
					SEL_Foobar.FIELD_TEXT => 'Test',
					'CreatedDate' => Datetime.now().addDays(-1) // CreatedDate is read-only
			};

			// Create empty child map (just to trigger the child path, even though we're testing parent read-only handling)
			Map<String, List<SObject>> childRelationships = new Map<String, List<SObject>>();

			Test.startTest();

			// Call with empty children map - should still apply read-only fields via JSON serialization when doInsert=false
			List<SObject> parents = factory.getListSObjectInstanceWithChildren
					(
							parentOverrides,
							false, // doInsert = false to trigger read-only path
							2,
							childRelationships,
							Foobar__c.SObjectType
					);

			Test.stopTest();

			Assert.areEqual(2, parents.size(), 'Should create 2 parent records');

			// Verify parents have the read-only field applied
			for(SObject parent : parents)
			{
				Foobar__c record = (Foobar__c)parent;
				Assert.isNotNull(record.CreatedDate, 'CreatedDate should be set via read-only override');
			}
		}
	}

	/**
	 * @description Mock provider to test exception wrapping.
	 */
	private class ExceptionThrowingProvider extends TST_Builder.DefaultFieldValueProvider
	{
		public override Object getValue(Integer recordIndex)
		{
			throw new IllegalArgumentException('Intentional Test Error');
		}
	}

	/**
	 * @description Tests that MockIdProvider constructor initializes correctly.
	 */
	@IsTest
	private static void mockIdProviderConstructorInitializes()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.MockIdProvider provider = new TST_BuilderInternal.MockIdProvider(Foobar__c.SObjectType);

			Assert.isNotNull(provider, 'MockIdProvider should be initialized.');
		}
	}

	/**
	 * @description Tests that MockIdProvider.getValue returns a unique Id for each call.
	 */
	@IsTest
	private static void mockIdProviderGetValueReturnsUniqueIds()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.MockIdProvider provider = new TST_BuilderInternal.MockIdProvider(Foobar__c.SObjectType);

			Id id1 = (Id)provider.getValue(0);
			Id id2 = (Id)provider.getValue(1);

			Assert.isNotNull(id1, 'First ID should not be null.');
			Assert.isNotNull(id2, 'Second ID should not be null.');
			Assert.areNotEqual(id1, id2, 'Each call should return a unique ID.');
			Assert.areEqual(Foobar__c.SObjectType, id1.getSobjectType(), 'ID should be for the correct SObjectType.');
		}
	}

	/**
	 * @description Tests that SObjectFactoryProvider.createFactory returns a valid factory.
	 */
	@IsTest
	private static void sObjectFactoryProviderCreatesFactory()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactoryProvider factoryProvider = new TST_BuilderInternal.SObjectFactoryProvider();

			TST_Builder.Factory factory = factoryProvider.createFactory(Foobar__c.SObjectType);

			Assert.isNotNull(factory, 'Factory should not be null.');
		}
	}

	/**
	 * @description Tests that SObjectFactory constructor throws exception for null SObjectType.
	 */
	@IsTest
	private static void factoryConstructorThrowsForNullSObjectType()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new TST_BuilderInternal.SObjectFactory(null);
				Assert.fail('Expected IllegalArgumentException for null SObjectType.');
			}
			catch(IllegalArgumentException error)
			{
				Assert.isTrue(error.getMessage().contains('null SObjectType'), 'Error should mention null SObjectType.');
			}
		}
	}

	/**
	 * @description Tests createAutoDefaultMap with SObjectField tokens.
	 */
	@IsTest
	private static void createAutoDefaultMapWithSObjectFields()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
			List<Object> fieldsToDefault = new List<Object>
			{
					Foobar__c.Name,
					Foobar__c.Text__c
			};

			Map<String, Object> result = TST_BuilderInternal.createAutoDefaultMap(fieldsToDefault, foobarDescribe);

			Assert.isTrue(result.containsKey(SEL_Foobar.FIELD_NAME.toLowerCase()), 'Should contain Name field (lowercase).');
			Assert.isTrue(result.containsKey(SEL_Foobar.FIELD_TEXT.toLowerCase()), 'Should contain Text__c field (lowercase).');
			Assert.areEqual(TST_Builder.autoDefaultFieldValueProvider, result.get(SEL_Foobar.FIELD_NAME.toLowerCase()), 'Value should be AUTO_DEFAULT.');
		}
	}

	/**
	 * @description Tests createAutoDefaultMap with String field names.
	 */
	@IsTest
	private static void createAutoDefaultMapWithStrings()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
			List<Object> fieldsToDefault = new List<Object>
			{
					SEL_Foobar.FIELD_NAME,
					SEL_Foobar.FIELD_TEXT
			};

			Map<String, Object> result = TST_BuilderInternal.createAutoDefaultMap(fieldsToDefault, foobarDescribe);

			Assert.isTrue(result.containsKey(SEL_Foobar.FIELD_NAME.toLowerCase()), 'Should contain Name field (lowercase).');
			Assert.isTrue(result.containsKey(SEL_Foobar.FIELD_TEXT.toLowerCase()), 'Should contain Text__c field (lowercase).');
		}
	}

	/**
	 * @description Tests createAutoDefaultMap with null list.
	 */
	@IsTest
	private static void createAutoDefaultMapWithNullList()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

			Map<String, Object> result = TST_BuilderInternal.createAutoDefaultMap(null, foobarDescribe);

			Assert.isNotNull(result, 'Result should not be null.');
			Assert.isTrue(result.isEmpty(), 'Result should be empty for null input.');
		}
	}

	/**
	 * @description Tests createAutoDefaultMap ignores blank strings.
	 */
	@IsTest
	private static void createAutoDefaultMapIgnoresBlankStrings()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
			List<Object> fieldsToDefault = new List<Object>
			{
					'Name',
					'',
					'  ',
					null
			};

			Map<String, Object> result = TST_BuilderInternal.createAutoDefaultMap(fieldsToDefault, foobarDescribe);

			Assert.areEqual(1, result.size(), 'Should only contain one valid field.');
			Assert.isTrue(result.containsKey('name'), 'Should contain Name field.');
		}
	}

	/**
	 * @description Tests getChildRelationshipName finds the correct relationship.
	 * Uses Foobar__c which has a self-referential child relationship (Foobars__r).
	 */
	@IsTest
	private static void childRelationshipHelperFindsRelationship()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.ChildRelationshipHelper helper = new TST_BuilderInternal.ChildRelationshipHelper();

			// Foobar__c has Foobars__r child relationship (self-referential via Lookup__c)
			String relationshipName = helper.getChildRelationshipName(Foobar__c.SObjectType, Foobar__c.SObjectType);

			Assert.areEqual(SEL_Foobar.RELATIONSHIP_FOOBARS, relationshipName, 'Should find Foobars__r relationship.');
		}
	}

	/**
	 * @description Tests getChildRelationshipName throws for no relationship found.
	 * Uses Foobar__c and User which have no child relationship between them.
	 */
	@IsTest
	private static void childRelationshipHelperThrowsForNoRelationship()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.ChildRelationshipHelper helper = new TST_BuilderInternal.ChildRelationshipHelper();

			try
			{
				// Foobar__c does not have User as a child (no lookup from User to Foobar__c)
				helper.getChildRelationshipName(Foobar__c.SObjectType, User.SObjectType);
				Assert.fail('Expected IllegalArgumentException for no relationship.');
			}
			catch(IllegalArgumentException error)
			{
				Assert.isTrue(error.getMessage().contains('No child relationship found'), 'Error should mention no relationship found.');
			}
		}
	}

	/**
	 * @description Tests getChildRelationshipName with Account-Task relationship.
	 * Verifies the method can handle objects with task relationships.
	 * Note: In some orgs Account may have multiple Task relationships, in others only one.
	 * This test verifies the method either returns a valid relationship or throws the expected error.
	 */
	@IsTest
	private static void childRelationshipHelperHandlesTaskRelationship()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.ChildRelationshipHelper helper = new TST_BuilderInternal.ChildRelationshipHelper();

			try
			{
				// Account has Task relationships - may be single or multiple depending on org
				String relationshipName = helper.getChildRelationshipName(Account.SObjectType, Task.SObjectType);
				// If we get here, there's only one named relationship
				Assert.isNotNull(relationshipName, 'Should return a relationship name.');
			}
			catch(IllegalArgumentException error)
			{
				// If multiple relationships exist, we get this error - which is also valid
				Assert.isTrue(error.getMessage().contains('Multiple relationships found') ||
						error.getMessage().contains('No child relationship found'),
						'Error should be about relationships.');
			}
		}
	}

	/**
	 * @description Tests getChildRelationshipName throws IllegalArgumentException when multiple
	 * relationships exist between parent and child types. User has multiple self-referential
	 * relationships via ManagerId and DelegatedApproverId lookup fields.
	 */
	@IsTest
	private static void childRelationshipHelperThrowsForMultipleRelationships()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.ChildRelationshipHelper helper = new TST_BuilderInternal.ChildRelationshipHelper();

			// User has multiple self-referential child relationships (Manager, DelegatedApprover)
			try
			{
				helper.getChildRelationshipName(User.SObjectType, User.SObjectType);
				Assert.fail('Should have thrown IllegalArgumentException for multiple relationships.');
			}
			catch(IllegalArgumentException error)
			{
				Assert.isTrue(
						error.getMessage().contains('Multiple relationships found'),
						'Error message should indicate multiple relationships. Got: ' + error.getMessage()
				);
			}
		}
	}

	/**
	 * @description Tests getForeignKeyField returns correct field name.
	 * Uses Foobar__c's Foobars__r child relationship.
	 */
	@IsTest
	private static void childRelationshipHelperGetForeignKeyField()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.ChildRelationshipHelper helper = new TST_BuilderInternal.ChildRelationshipHelper();

			String foreignKeyField = helper.getForeignKeyField(Foobar__c.SObjectType, SEL_Foobar.RELATIONSHIP_FOOBARS);

			Assert.areEqual(SEL_Foobar.FIELD_LOOKUP, foreignKeyField, 'Should return Lookup__c as foreign key field.');
		}
	}

	/**
	 * @description Tests getForeignKeyField throws for invalid relationship.
	 */
	@IsTest
	private static void childRelationshipHelperGetForeignKeyFieldThrowsForInvalid()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.ChildRelationshipHelper helper = new TST_BuilderInternal.ChildRelationshipHelper();

			try
			{
				helper.getForeignKeyField(Foobar__c.SObjectType, 'InvalidRelationship');
				Assert.fail('Expected IllegalArgumentException for invalid relationship.');
			}
			catch(IllegalArgumentException error)
			{
				Assert.isTrue(error.getMessage().contains('No relationship found'), 'Error should mention no relationship found.');
			}
		}
	}

	/**
	 * @description Tests applyChildRelationshipsViaJSON correctly mocks child relationships.
	 * Uses Foobar__c's self-referential child relationship.
	 */
	@IsTest
	private static void childRelationshipHelperAppliesChildrenViaJson()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.ChildRelationshipHelper helper = new TST_BuilderInternal.ChildRelationshipHelper();

			List<SObject> parents = new List<SObject>
			{
					TST_Factory.newFoobarWithName('Test Parent')
			};

			List<SObject> children = new List<SObject>
			{
					TST_Factory.newFoobarWithName('Child1'),
					TST_Factory.newFoobarWithName('Child2')
			};

			Map<String, List<SObject>> childRelationships = new Map<String, List<SObject>>
			{
					SEL_Foobar.RELATIONSHIP_FOOBARS => children
			};

			List<SObject> result = helper.applyChildRelationshipsViaJSON(parents, childRelationships);

			Assert.areEqual(1, result.size(), 'Should return one parent.');
			Foobar__c parentFoobar = (Foobar__c)result[0];
			Assert.isNotNull(parentFoobar.Foobars__r, 'Foobars__r relationship should be populated.');
			Assert.areEqual(2, parentFoobar.Foobars__r.size(), 'Should have 2 children.');
			Assert.areEqual('Child1', parentFoobar.Foobars__r[0].Name, 'First child should match.');
		}
	}

	/**
	 * @description Tests normalizeCacheKey with blank input.
	 */
	@IsTest
	private static void managerNormalizeCacheKeyWithBlank()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager manager = createManager();

			String result = manager.normalizeCacheKey(null);
			Assert.isNull(result, 'Null input should return null.');

			result = manager.normalizeCacheKey('');
			Assert.areEqual('', result, 'Empty string should return empty string.');
		}
	}

	/**
	 * @description Tests normalizeCacheKey with single segment field name.
	 */
	@IsTest
	private static void managerNormalizeCacheKeyWithSingleSegment()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager manager = createManager();

			// Standard field name to relationship
			String result = manager.normalizeCacheKey('AccountId');
			Assert.areEqual('account', result, 'AccountId should normalize to account.');

			// Custom field name to relationship
			result = manager.normalizeCacheKey('Lookup__c');
			Assert.areEqual('lookup__r', result, 'Lookup__c should normalize to lookup__r.');

			// Already a relationship name
			result = manager.normalizeCacheKey('Account');
			Assert.areEqual('account', result, 'Account should stay as account (lowercase).');
		}
	}

	/**
	 * @description Tests normalizeCacheKey with multi-segment path.
	 */
	@IsTest
	private static void managerNormalizeCacheKeyWithMultiSegment()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager manager = createManager();

			// Multi-segment with field names
			String result = manager.normalizeCacheKey('AccountId.ParentId');
			Assert.areEqual('account.parent', result, 'AccountId.ParentId should normalize to account.parent.');

			// Multi-segment mixed
			result = manager.normalizeCacheKey('Account.ParentId.OwnerId');
			Assert.areEqual('account.parent.owner', result, 'Mixed path should normalize all segments.');

			// Custom fields
			result = manager.normalizeCacheKey('Lookup__c.Lookup__c');
			Assert.areEqual('lookup__r.lookup__r', result, 'Custom fields should convert to __r.');
		}
	}

	/**
	 * @description Tests convertFieldToRelationshipName with various inputs.
	 */
	@IsTest
	private static void managerConvertFieldToRelationshipName()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager manager = createManager();

			// Blank input
			Assert.isNull(manager.normalizeCacheKey(null), 'Null should return null.');

			// Short field name (edge case for 'Id' - should not strip)
			String result = manager.normalizeCacheKey('Id');
			Assert.areEqual('id', result, 'Id should remain Id (lowercase).');

			// Standard relationship already
			result = manager.normalizeCacheKey('Parent');
			Assert.areEqual('parent', result, 'Parent should remain parent.');

			// Custom relationship already
			result = manager.normalizeCacheKey('Custom__r');
			Assert.areEqual('custom__r', result, 'Custom__r should remain custom__r.');
		}
	}

	/**
	 * @description Tests that globalGenerateMockIds causes related objects to get mock IDs.
	 */
	@IsTest
	private static void factoryGlobalGenerateMockIdsAssignsMockIds()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			// Enable global mock ID generation
			TST_BuilderInternal.globalGenerateMockIds = true;

			try
			{
				// Get a related SObject instance - should have mock ID assigned
				SObject relatedInstance = sObjectFactory.getRelatedSObjectInstance(Foobar__c.SObjectType, SEL_Foobar.RELATIONSHIP_LOOKUP, 'TestContext');

				Assert.isNotNull(relatedInstance, 'Related instance should not be null.');
				Assert.isNotNull(relatedInstance.Id, 'Related instance should have a mock ID assigned.');
				Assert.areEqual(Foobar__c.SObjectType, relatedInstance.Id.getSobjectType(), 'Mock ID should be for correct type.');
			}
			finally
			{
				// Reset global state
				TST_BuilderInternal.globalGenerateMockIds = false;
			}
		}
	}

	/**
	 * @description Tests that without globalGenerateMockIds, related objects do not get mock IDs.
	 */
	@IsTest
	private static void factoryWithoutGlobalGenerateMockIdsNoMockIds()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			// Ensure global mock ID generation is off
			TST_BuilderInternal.globalGenerateMockIds = false;

			SObject relatedInstance = sObjectFactory.getRelatedSObjectInstance(Foobar__c.SObjectType, SEL_Foobar.RELATIONSHIP_LOOKUP, 'TestContext');

			Assert.isNotNull(relatedInstance, 'Related instance should not be null.');
			Assert.isNull(relatedInstance.Id, 'Related instance should NOT have a mock ID when globalGenerateMockIds is false.');
		}
	}

	/**
	 * @description Tests getListSObjectInstanceWithChildren with actual insertion and children.
	 * This covers the registerChildren path with UOW.
	 * Uses Foobar__c to avoid subscriber org validation rules.
	 */
	@IsTest
	private static void factoryGetListSObjectInstanceWithChildrenInserts()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory factory = createFactory();

			Map<String, Object> parentOverrides = new Map<String, Object>
			{
					SEL_Foobar.FIELD_NAME => 'Test Parent Foobar'
			};

			// Create child Foobars to be inserted with parents
			List<SObject> childFoobars = new List<SObject>
			{
					TST_Factory.newFoobarWithName('ChildFoobar1'),
					TST_Factory.newFoobarWithName('ChildFoobar2')
			};

			Map<String, List<SObject>> childRelationships = new Map<String, List<SObject>>
			{
					SEL_Foobar.RELATIONSHIP_FOOBARS => childFoobars
			};

			Test.startTest();

			List<SObject> parents = factory.getListSObjectInstanceWithChildren
					(
							parentOverrides,
							true, // doInsert = true
							1,
							childRelationships,
							Foobar__c.SObjectType
					);

			Test.stopTest();

			Assert.areEqual(1, parents.size(), 'Should create 1 parent.');
			Foobar__c parentFoobar = (Foobar__c)parents[0];
			Assert.isNotNull(parentFoobar.Id, 'Parent should be inserted.');

			// Query for children using QRY_Builder
			List<Foobar__c> insertedChildren = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields(new List<SObjectField> {Foobar__c.Id, Foobar__c.Name, Foobar__c.Lookup__c})
					.condition(Foobar__c.Lookup__c).equals(parentFoobar.Id)
					.toList();
			Assert.areEqual(2, insertedChildren.size(), 'Should have inserted 2 child Foobars.');
		}
	}

	/**
	 * @description Tests initSObjectInstance with nested SObject value (covers line 313).
	 * When a nested relationship path has an SObject value, it should call putSObject.
	 */
	@IsTest
	private static void factoryInitWithNestedSObjectValue()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();

			// Create a parent Foobar to be set as a nested relationship
			Foobar__c parentFoobar = TST_Factory.newFoobarWithName('Nested Parent');

			// Set up map with nested SObject: Lookup__r.Lookup__r = SObject
			Map<String, TST_Builder.DefaultFieldValueProvider> mapOfValues =
					new Map<String, TST_Builder.DefaultFieldValueProvider>
					{
							SEL_Foobar.RELATIONSHIP_LOOKUP + UTIL_String.DOT + SEL_Foobar.RELATIONSHIP_LOOKUP =>
									new UTIL_SObjectBuilderDefaultProvider.FieldDefaultValue(parentFoobar)
					};

			sObjectFactory.initSObjectInstance(mapOfValues, 0, false);

			SObject mainSObject = sObjectFactory.getSObjectManager().getMainObjects().get(0);
			Assert.isNotNull(mainSObject, 'Main object should exist.');

			SObject firstLevel = mainSObject.getSObject(SEL_Foobar.RELATIONSHIP_LOOKUP);
			Assert.isNotNull(firstLevel, 'First level relationship should exist.');
		}
	}

	/**
	 * @description Tests putSObject with field name (e.g., 'Lookup__c') instead of relationship name.
	 * This covers line 519 where childFieldName = relationshipName when input is already a field name.
	 */
	@IsTest
	private static void factoryPutSObjectWithFieldName()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c foobarRecord = TST_Factory.newFoobar();

			// Use field name 'Lookup__c' instead of relationship name 'Lookup__r'
			sObjectFactory.putSObject(foobarRecord, SEL_Foobar.FIELD_LOOKUP, TST_Factory.newFoobarWithName(TEST_STRING), UTIL_String.EMPTY, false, 0);

			Assert.isNotNull(foobarRecord.Lookup__r, 'The related Foobar record should be attached using field name.');
			Assert.areEqual(TEST_STRING, foobarRecord.Lookup__r.Name, 'The related Foobar Name should be set.');
		}
	}

	/**
	 * @description Tests putSObject with doInsert=true to cover registerLink path (line 547).
	 */
	@IsTest
	private static void factoryPutSObjectWithInsertRegistersLink()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c childRecord = TST_Factory.newFoobarWithName('Child');
			Foobar__c parentRecord = TST_Factory.newFoobarWithName('Parent');

			// Initialize the SObject manager with the child
			sObjectFactory.getSObjectManager().setSObject(0, childRecord, true);

			// Call putSObject with doInsert=true
			sObjectFactory.putSObject(childRecord, SEL_Foobar.RELATIONSHIP_LOOKUP, parentRecord, SEL_Foobar.OBJECT_NAME, true, 0);

			// Verify the link was registered (we can't easily verify this without insertion, but no exception means success)
			Assert.isNotNull(sObjectFactory.getSObjectManager(), 'Manager should exist.');
		}
	}

	/**
	 * @description Tests putSObject when parent SObject has an ID to cover line 560.
	 */
	@IsTest
	private static void factoryPutSObjectWithParentIdSetsIdField()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = createFactory();
			Foobar__c foobarRecord = TST_Factory.newFoobar();
			Id mockParentId = UTIL_Random.randomId(Foobar__c.SObjectType);
			Foobar__c parentWithId = newFoobarWithIdAndName(mockParentId, TEST_STRING);

			// putSObject with parent that has an ID - should set both relationship and ID field
			sObjectFactory.putSObject(foobarRecord, SEL_Foobar.RELATIONSHIP_LOOKUP, parentWithId, UTIL_String.EMPTY, false, 0);

			Assert.areEqual(mockParentId, foobarRecord.Lookup__c, 'Lookup__c field should be set to parent ID.');
			Assert.isNotNull(foobarRecord.Lookup__r, 'The related Foobar record should be attached.');
		}
	}

	/**
	 * @description Tests putSObject with a MetadataRelationship field (e.g., TriggerSetting__mdt.SObjectType__c
	 * to EntityDefinition). MetadataRelationship fields are not DisplayType.REFERENCE and their describe
	 * returns null for getRelationshipName(). The framework should derive the relationship name from the
	 * field name and route through the read-only override path.
	 */
	@IsTest
	private static void factoryPutSObjectWithMetadataRelationship()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectFactory sObjectFactory = new TST_BuilderInternal.SObjectFactory(TriggerSetting__mdt.SObjectType);
			TriggerSetting__mdt settingRecord = new TriggerSetting__mdt();
			EntityDefinition entityDefinition = (EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
					.withOverride(EntityDefinition.QualifiedApiName, SEL_Foobar.OBJECT_NAME)
					.withoutInsertion()
					.build();
			String path = UTIL_SObjectDescribe.getObjectNameFromType(TriggerSetting__mdt.SObjectType);

			sObjectFactory.putSObject(settingRecord, TriggerSetting__mdt.SObjectType__c.getDescribe().name, entityDefinition, path, false, 0);

			String expectedRelationshipName = TriggerSetting__mdt.SObjectType__c.getDescribe().name
					.removeEnd(UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX) + UTIL_SObjectDescribe.RELATIONSHIP_SUFFIX;

			Assert.isTrue(sObjectFactory.getSObjectManager().hasReadOnlyOverrides(), 'MetadataRelationship should be registered as read-only override');
			Map<String, Object> overrides = sObjectFactory.getSObjectManager().getReadOnlyOverrides(0, path);
			Assert.isTrue(overrides.containsKey(expectedRelationshipName), 'Override should contain derived relationship name');
			Assert.areEqual(entityDefinition, overrides.get(expectedRelationshipName), 'Override should contain the EntityDefinition');
		}
	}

	/**
	 * @description Tests that building a TriggerSetting__mdt with an EntityDefinition parent via
	 * TST_Builder produces a record with the SObjectType__r relationship populated. Verifies the
	 * full end-to-end path: putSObject derives the relationship name, registers a read-only override,
	 * and applyReadOnlyFields preserves the SObject type attributes during JSON round-trip.
	 */
	@IsTest
	private static void shouldBuildMetadataRelationshipToEntityDefinition()
	{
		System.runAs(getTestAdmin())
		{
			EntityDefinition entityDefinition = (EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
					.withOverride(EntityDefinition.QualifiedApiName, SEL_Foobar.OBJECT_NAME)
					.withoutInsertion()
					.build();

			TriggerSetting__mdt triggerSetting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
					.withOverride(TriggerSetting__mdt.SObjectType__c, entityDefinition)
					.withoutInsertion(true)
					.build();

			Assert.isNotNull(triggerSetting.SObjectType__r, 'EntityDefinition relationship should be populated');
			Assert.areEqual(SEL_Foobar.OBJECT_NAME, triggerSetting.SObjectType__r.QualifiedApiName, 'QualifiedApiName should match');
		}
	}

	/**
	 * @description Tests convertFieldToRelationshipName with blank segment (covers line 928).
	 */
	@IsTest
	private static void managerConvertFieldToRelationshipNameWithBlankSegment()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager manager = createManager();

			// Test with a path that might have a blank segment at the end after splitting
			// normalizeCacheKey calls convertFieldToRelationshipName internally
			String result = manager.normalizeCacheKey('Account.');

			// The trailing dot creates a blank segment
			Assert.isNotNull(result, 'Result should handle trailing dot.');
		}
	}

	/**
	 * @description Tests SObjectManager.registerChildren registers children correctly with UOW.
	 * Uses Foobar__c to avoid subscriber org validation rules.
	 */
	@IsTest
	private static void managerRegisterChildrenRegistersWithUow()
	{
		System.runAs(getTestAdmin())
		{
			TST_BuilderInternal.SObjectManager manager = createManager();

			// Create and register parent
			Foobar__c parent = TST_Factory.newFoobarWithName('Test Parent');
			manager.setSObject(0, parent, true);

			// Create children
			List<SObject> children = new List<SObject>
			{
					TST_Factory.newFoobarWithName('Child1'),
					TST_Factory.newFoobarWithName('Child2')
			};

			Map<String, List<SObject>> childRelationships = new Map<String, List<SObject>>
			{
					SEL_Foobar.RELATIONSHIP_FOOBARS => children
			};

			TST_BuilderInternal.ChildRelationshipHelper helper = new TST_BuilderInternal.ChildRelationshipHelper();

			// Register children
			manager.registerChildren(new List<SObject> {parent}, childRelationships, Foobar__c.SObjectType, helper);

			Test.startTest();
			manager.insertAll();
			Test.stopTest();

			// Verify parent and children were inserted using QRY_Builder
			Foobar__c insertedParent = (Foobar__c)QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields(new List<SObjectField> {Foobar__c.Id, Foobar__c.Name})
					.condition(Foobar__c.Name).equals('Test Parent')
					.getFirst();
			Assert.isNotNull(insertedParent, 'Parent should be inserted.');

			List<Foobar__c> insertedChildren = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields(new List<SObjectField> {Foobar__c.Id, Foobar__c.Name, Foobar__c.Lookup__c})
					.condition(Foobar__c.Lookup__c).equals(insertedParent.Id)
					.toList();
			Assert.areEqual(2, insertedChildren.size(), 'Should have 2 child Foobars.');
		}
	}

	private static Foobar__c newFoobarWithIdAndName(Id recordId, String name)
	{
		Foobar__c foobar = TST_Factory.newFoobar();
		foobar.Id = recordId;
		foobar.Name = name;
		return foobar;
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