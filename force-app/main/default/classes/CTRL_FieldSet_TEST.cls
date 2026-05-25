// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class related to the CTRL_FieldSet
 *
 * @see CTRL_FieldSet
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity')
@IsTest(SeeAllData=false IsParallel=false)
private class CTRL_FieldSet_TEST
{
	private static final List<String> FOOBAR_FIELD_SETS = new List<String>
	{
			SEL_Foobar.FIELDSET_AUDIT,
			SEL_Foobar.FIELDSET_PERSON,
			UTIL_Random.randomName() //This invalid fieldset names is added to check that it's ignored
	};

	private static final String TEST_ADMIN_COMPANY = 'CTRL_FieldSet_TEST-admin';
	private static final String ERROR_API_NAMES_MISMATCH = 'Api Names do not match';
	private static final String ERROR_MEMBER_INCORRECT = 'Dto member information is incorrect';
	private static final String ERROR_NO_FIELDS_FOUND_AS_EXPECTED = 'No field was found in the Foobar fieldSet.';
	private static final String ERROR_NO_RECORDS_FOUND_AS_EXPECTED = 'Custom Metadata record not found as expected';

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

	@IsTest
	private static void getDefaultActiveSectionsField()
	{
		System.runAs(getTestAdmin())
		{
			CTRL_FieldSet.DTO_FieldSetGroupApiNames dtoImport = CTRL_FieldSet.getDefaultActiveSectionsField();

			Assert.areEqual(SEL_FieldSetGroup.OBJECT_NAME, dtoImport.objectApiName, ERROR_API_NAMES_MISMATCH);
			Assert.areEqual(SEL_FieldSetGroup.FIELD_DEFAULT_ACTIVE_SECTIONS, dtoImport.fieldApiName, ERROR_API_NAMES_MISMATCH);
		}
	}

	@IsTest
	private static void getFieldSetApiNamesField()
	{
		System.runAs(getTestAdmin())
		{
			CTRL_FieldSet.DTO_FieldSetGroupApiNames dtoImport = CTRL_FieldSet.getFieldSetApiNamesField();

			Assert.areEqual(SEL_FieldSetGroup.OBJECT_NAME, dtoImport.objectApiName, ERROR_API_NAMES_MISMATCH);
			Assert.areEqual(SEL_FieldSetGroup.FIELD_FIELDSET_API_NAMES, dtoImport.fieldApiName, ERROR_API_NAMES_MISMATCH);
		}
	}

	/**
	 * @description Will check if all of the fields are retrieved from the field set for FooBar object Id
	 *
	 * @see CTRL_FieldSet.getFieldSetsForRecord
	 */
	@IsTest
	private static void getFieldSetsForRecord()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(FOOBAR_FIELD_SETS.size());

			Map<String, FieldSet> fieldSetMap = UTIL_SObjectDescribe.getDescribe(SEL_Foobar.OBJECT_NAME).getFieldSetsMap();
			List<Foobar__c> foundFoobars = getAll(fieldSetMap);

			Map<Id, List<String>> requestMap = new Map<Id, List<String>>();
			for(Integer i = 0; i < foundFoobars.size(); i++)
			{
				requestMap.put(foundFoobars[i].Id, new List<String> {FOOBAR_FIELD_SETS[i]});
			}

			//This will check that this record is ignored as no fieldset names were provided
			requestMap.put(UTIL_Random.randomId(Foobar__c.SObjectType), null);
			//This will check that this record is ignored as the object doesn't have any fieldset
			requestMap.put(UTIL_Random.randomId(EmailTemplate.SObjectType), FOOBAR_FIELD_SETS);

			fieldSetMap = UTIL_SObjectDescribe.getDescribe(LogEntry__c.SObjectType).getFieldSetsMap();
			FieldSet foundFieldSet = fieldSetMap.get(SEL_LogEntry.FIELD_SET_TEST);

			Assert.isNotNull(foundFieldSet, 'Fieldset for Log Entry missing');

			LogEntry__c logEntry = TST_Factory.insertLogEntry();
			SObject foundLogEntry = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
					.fields(new List<String>(CTRL_FieldSet.getFieldNamesFromFieldSetMember(foundFieldSet.fields)))
					.condition('Id').equals(logEntry.Id)
					.getFirst();

			//This will check a separate query will be run for different object
			requestMap.put(foundLogEntry.Id, new List<String> {SEL_LogEntry.FIELD_SET_TEST});

			Test.startTest();

			Map<Id, Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>>> fieldSetsByRecordId = CTRL_FieldSet.getFieldSetsForRecord(requestMap);
			Assert.areEqual(2, UTIL_Limits.soqlQueries().used(), 'Only expected a query to be generated for each object type');

			Test.stopTest();

			assertFieldSetInformationCorrect(foundFoobars, fieldSetsByRecordId);
		}
	}

	/**
	 * @description Will query all foobars using the fields from the field sets
	 *
	 * @param fieldSetMap A map of fieldset by name
	 *
	 * @return A list of found items
	 */
	private static List<Foobar__c> getAll(Map<String, FieldSet> fieldSetMap)
	{
		Set<String> allFoobarFields = new Set<String>();

		for(String fieldsetName : FOOBAR_FIELD_SETS)
		{
			FieldSet foundFieldSet = fieldSetMap.get(fieldsetName);
			if(foundFieldSet != null)
			{
				//Ensures we query all the foobar fields need based on the field sets provided
				allFoobarFields.addAll(CTRL_FieldSet.getFieldNamesFromFieldSetMember(foundFieldSet.fields));
			}
		}

		return QRY_Builder.selectFrom(Foobar__c.SObjectType).fields(new List<String>(allFoobarFields)).toList();
	}

	/**
	 * @description Will check that the field set information returned is correct
	 *
	 * @param foundFoobars The foobars for which field values were requested
	 * @param fieldSetsByRecordId The field set and field values
	 */
	private static void assertFieldSetInformationCorrect(List<Foobar__c> foundFoobars, Map<Id, Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>>> fieldSetsByRecordId)
	{
		Assert.isFalse(fieldSetsByRecordId.isEmpty(), ERROR_NO_FIELDS_FOUND_AS_EXPECTED);

		//Since once of the field set names is invalid, one of the requests won't have results returned but results set includes fields for LogEntry record
		Assert.areEqual(foundFoobars.size() - 1, fieldSetsByRecordId.size() - 1, 'Incorrect number of records returned');

		for(Integer i = 0; i < fieldSetsByRecordId.size(); i++)
		{
			SObject foundObject = foundFoobars[i];

			Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>> fieldSetMemberMap = fieldSetsByRecordId.get(foundObject.Id);

			//For one of the foobars created there will be no results returned as the fieldset name provided is invalid
			if(fieldSetMemberMap == null)
			{
				continue;
			}

			assertDtoMemberCorrect
					(
							foundObject,
							UTIL_SObjectDescribe.getObjectNameFromType(foundObject.getSObjectType()),
							FOOBAR_FIELD_SETS[i],
							fieldSetMemberMap.get(FOOBAR_FIELD_SETS[i])
					);
		}
	}

	/**
	 * @description Checks that the members are correct for the given fieldset
	 *
	 * @param anObject The SObject for which the fieldset was requested
	 * @param objectName The name of the object to check
	 * @param fieldsetName The name of the fieldset to check
	 * @param fieldSetMembers The Dto members that were returned
	 */
	private static void assertDtoMemberCorrect(SObject anObject, String objectName, String fieldsetName, List<CTRL_FieldSet.DTO_FieldSetMember> fieldSetMembers)
	{
		Assert.isNotNull(fieldSetMembers, 'No fieldset members returned');

		FieldSet foundFieldSet = UTIL_SObjectDescribe.getDescribe(objectName).getFieldSetsMap().get(fieldsetName);

		Assert.areEqual(foundFieldSet.fields.size(), fieldSetMembers.size(), 'Incorrect number of members');

		for(Integer j = 0; j < foundFieldSet.fields.size(); j++)
		{
			FieldSetMember member = foundFieldSet.fields[j];

			CTRL_FieldSet.DTO_FieldSetMember dtoMember = fieldSetMembers[j];

			Assert.areEqual(SEL_Foobar.OBJECT_NAME, dtoMember.objectName, ERROR_MEMBER_INCORRECT);
			Assert.areEqual(UTIL_SObject.getFieldValue(anObject, member.fieldPath), dtoMember.fieldValue, ERROR_MEMBER_INCORRECT);
			Assert.areEqual(foundFieldSet.label, dtoMember.fieldSetName, ERROR_MEMBER_INCORRECT);
			Assert.areEqual(UTIL_System.getNamespacePrefix(foundFieldSet.nameSpace) + foundFieldSet.name, dtoMember.fieldSetAPIName, ERROR_MEMBER_INCORRECT);
			Assert.areEqual(member.dbRequired || member.required, dtoMember.isRequired, ERROR_MEMBER_INCORRECT);
			Assert.areEqual(member.fieldPath, dtoMember.fieldAPIName, ERROR_MEMBER_INCORRECT);
			Assert.areEqual(member.label, dtoMember.fieldLabel, ERROR_MEMBER_INCORRECT);
			Assert.areEqual(member.type.name(), dtoMember.fieldType, ERROR_MEMBER_INCORRECT);
		}
	}

	/**
	 * @description Will check if all of the fields are retrieved from the field set for FooBar object Name
	 *
	 * @see CTRL_FieldSet.getFieldSetsForObject
	 */
	@IsTest
	private static void getFieldSetsForObject()
	{
		System.runAs(getTestAdmin())
		{
			Map<String, List<String>> requestMap = new Map<String, List<String>>();

			requestMap.put(SEL_Foobar.OBJECT_NAME, FOOBAR_FIELD_SETS);

			Test.startTest();

			Map<String, Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>>> fieldDetailsByObjectName = CTRL_FieldSet.getFieldSetsForObject(requestMap);

			Test.stopTest();

			Assert.isFalse(fieldDetailsByObjectName.isEmpty(), ERROR_NO_FIELDS_FOUND_AS_EXPECTED);
			Assert.areEqual(1, fieldDetailsByObjectName.size(), 'Only expected entry for single object');

			for(String objectName : fieldDetailsByObjectName.keySet())
			{
				Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>> fieldSetMemberMap = fieldDetailsByObjectName.get(objectName);

				for(String fieldSetName : fieldSetMemberMap.keySet())
				{
					assertDtoMemberCorrect(null, objectName, fieldSetName, fieldSetMemberMap.get(fieldSetName));
				}
			}
		}
	}

	/**
	 * @description Will check if FieldSetGroup__mdt custom metadata records are retrieved as expected
	 *
	 * @see CTRL_FieldSet.findByDeveloperName
	 */
	@IsTest
	private static void findByDeveloperName()
	{
		System.runAs(getTestAdmin())
		{
			FieldSetGroup__mdt mockRecord = (FieldSetGroup__mdt)TST_Mock.of(FieldSetGroup__mdt.SObjectType)
					.withOverride(FieldSetGroup__mdt.DeveloperName, 'TestFieldSetGroup')
					.withOverride(FieldSetGroup__mdt.DefaultActiveSections__c, 'Default')
					.withOverride(FieldSetGroup__mdt.FieldSetApiNames__c, 'Default')
					.build();

			Test.startTest();

			FieldSetGroup__mdt result = CTRL_FieldSet.findByDeveloperName('TestFieldSetGroup');

			Test.stopTest();

			Assert.areEqual(mockRecord.DeveloperName, result.DeveloperName, ERROR_NO_RECORDS_FOUND_AS_EXPECTED);
		}
	}

	/**
	 * @description Checks that the controller returns the API name for the provided Id
	 *
	 * @see CTRL_FieldSet.getObjectNameFromId
	 */
	@IsTest
	private static void getObjectNameFromId()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			String objectAPIName = CTRL_FieldSet.getObjectNameFromId(UTIL_Random.randomId(Foobar__c.SObjectType));

			Test.stopTest();

			Assert.areEqual(SEL_Foobar.OBJECT_NAME, objectAPIName, ERROR_API_NAMES_MISMATCH);
		}
	}

	/**
	 * @description Checks that the controller returns relevant fieldset information
	 */
	@IsTest
	private static void searchWithRecordId()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(FOOBAR_FIELD_SETS.size());

			Foobar__c foundFoobar = getAll(UTIL_SObjectDescribe.getDescribe(SEL_Foobar.OBJECT_NAME).getFieldSetsMap()).iterator().next();

			Map<String, Object> searchParameters = new Map<String, Object>();

			searchParameters.put(CTRL_FieldSet.PARAMETER_FIELD_SET_LIST, FOOBAR_FIELD_SETS);
			searchParameters.put(CTRL_FieldSet.PARAMETER_RECORD_ID, foundFoobar.Id);

			Test.startTest();

			Object searchResults = CTRL_FieldSet.search(UTIL_String.EMPTY, searchParameters);

			Test.stopTest();

			Assert.isNotNull(searchResults, 'No result object returned');

			Map<Id, Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>>> fieldSetsByRecordId =
					(Map<Id, Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>>>)searchResults;

			Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>> fieldSetMemberMap = fieldSetsByRecordId.get(foundFoobar.Id);
			Assert.isNotNull(fieldSetMemberMap, 'No fieldset information returned');

			for(String fieldSetName : fieldSetMemberMap.keySet())
			{
				assertDtoMemberCorrect(foundFoobar, SEL_Foobar.OBJECT_NAME, fieldSetName, fieldSetMemberMap.get(fieldSetName));
			}
		}
	}

	/**
	 * @description Checks that the controller returns relevant fieldset information
	 */
	@IsTest
	private static void searchWithObjectName()
	{
		System.runAs(getTestAdmin())
		{
			Map<String, Object> searchParameters = new Map<String, Object>();

			searchParameters.put(CTRL_FieldSet.PARAMETER_FIELD_SET_LIST, FOOBAR_FIELD_SETS);
			searchParameters.put(CTRL_FieldSet.PARAMETER_OBJECT_NAME, SEL_Foobar.OBJECT_NAME);

			Test.startTest();

			Object searchResults = CTRL_FieldSet.search(UTIL_String.EMPTY, searchParameters);

			Test.stopTest();

			Assert.isNotNull(searchResults, 'No result object returned');

			Map<String, Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>>> fieldSetMemberMapsByObjectName =
					(Map<String, Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>>>)searchResults;

			Map<String, List<CTRL_FieldSet.DTO_FieldSetMember>> fieldSetMemberMap = fieldSetMemberMapsByObjectName.get(SEL_Foobar.OBJECT_NAME);
			Assert.isNotNull(fieldSetMemberMap, 'No fieldset information returned');

			for(String fieldSetName : fieldSetMemberMap.keySet())
			{
				assertDtoMemberCorrect(null, SEL_Foobar.OBJECT_NAME, fieldSetName, fieldSetMemberMap.get(fieldSetName));
			}
		}
	}

	/**
	 * @description Checks that the controller throws an error if parameters provided are incorrect
	 */
	@IsTest
	private static void errorFieldSetParameterNotProvided()
	{
		System.runAs(getTestAdmin())
		{
			assertCorrectErrorThrown(new Map<String, Object>(), CTRL_FieldSet.ERROR_FIELD_SET_LIST_NOT_PROVIDED);
		}
	}

	/**
	 * @description Will check that the search method fails and the correct error is thrown
	 *
	 * @param searchParameters The parameters to use
	 * @param errorMessage The expected error message
	 */
	private static void assertCorrectErrorThrown(Map<String, Object> searchParameters, String errorMessage)
	{
		Test.startTest();

		try
		{
			CTRL_FieldSet.search(UTIL_String.EMPTY, searchParameters);
			Assert.fail('Expected an exception to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Thrown');
			Assert.areEqual(error.getMessage(), errorMessage, 'Incorrect Error Message');
		}

		Test.stopTest();
	}

	/**
	 * @description Checks that the controller throws an error if parameters provided are incorrect
	 */
	@IsTest
	private static void errorRecordIdParameterNotProvided()
	{
		System.runAs(getTestAdmin())
		{
			Map<String, Object> searchParameters = new Map<String, Object>();
			searchParameters.put(CTRL_FieldSet.PARAMETER_FIELD_SET_LIST, FOOBAR_FIELD_SETS);

			assertCorrectErrorThrown(searchParameters, CTRL_FieldSet.ERROR_RECORD_ID_OR_OBJECT_NAME_NOT_PROVIDED);
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