// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Validates the SObject metadata controller methods against the Foobar__c object.
 *
 * @see CTRL_SObjectInformation
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class CTRL_SObjectInformation_TEST
{
	/**
	 * @description The object used for all metadata assertions.
	 */
	private static final String TARGET_OBJECT = SEL_Foobar.OBJECT_NAME;

	/**
	 * @description Verifies all fields are returned for the target object.
	 */
	@IsTest
	private static void shouldReturnAllFieldMetadata()
	{
		Test.startTest();
		Map<String, CTRL_SObjectInformation.DTO_FieldInformation> fields =
				CTRL_SObjectInformation.getSObjectAllFieldsInformation(TARGET_OBJECT);
		Test.stopTest();

		Assert.isTrue(fields.keySet().size() > 1, 'Should return multiple fields');
		Assert.isNotNull(fields.get('Name'), 'Name field should be present');
	}

	/**
	 * @description Verifies a specific field is returned with correct metadata.
	 */
	@IsTest
	private static void shouldReturnRequestedFieldMetadata()
	{
		Test.startTest();
		Map<String, CTRL_SObjectInformation.DTO_FieldInformation> fields =
				CTRL_SObjectInformation.getSObjectFieldInformation(TARGET_OBJECT, new List<String> {'Name'});
		Test.stopTest();

		CTRL_SObjectInformation.DTO_FieldInformation nameField = fields.get('Name');
		Assert.isNotNull(nameField, 'Name field should be included');
	}

	/**
	 * @description Verifies null is returned when objectName is blank.
	 */
	@IsTest
	private static void shouldReturnNullForBlankObjectName()
	{
		Test.startTest();
		Map<String, CTRL_SObjectInformation.DTO_FieldInformation> result =
				CTRL_SObjectInformation.getSObjectFieldInformation('', new List<String> {'Name'});
		Test.stopTest();

		Assert.isNull(result, 'Should return null for blank objectName');
	}

	/**
	 * @description Verifies lookup fields include the referenced object API name
	 * and non-existent fields are silently skipped.
	 */
	@IsTest
	private static void shouldReturnLookupFieldAndSkipNonExistent()
	{
		String lookupFieldName = SEL_Foobar.FIELD_LOOKUP;

		Test.startTest();
		Map<String, CTRL_SObjectInformation.DTO_FieldInformation> fields =
				CTRL_SObjectInformation.getSObjectFieldInformation(TARGET_OBJECT, new List<String> {lookupFieldName, 'NonExistentField__x'});
		Test.stopTest();

		Assert.areEqual(1, fields.size(), 'Non-existent field should be skipped');
		CTRL_SObjectInformation.DTO_FieldInformation lookupField = fields.get(lookupFieldName);
		Assert.isNotNull(lookupField, 'Lookup field should be included');
		Assert.areEqual('REFERENCE', lookupField.fieldType, 'Field type should be REFERENCE');
		Assert.isNotNull(lookupField.lookupObjectApiName, 'Lookup object API name should be populated');
	}

	/**
	 * @description Verifies record type count matches the describe result.
	 */
	@IsTest
	private static void shouldReturnRecordTypes()
	{
		Test.startTest();
		List<CTRL_SObjectInformation.DTO_RecordTypeInformation> recordTypes =
				CTRL_SObjectInformation.getRecordTypes(TARGET_OBJECT);
		Test.stopTest();

		Integer expected = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType).getDescribe().recordTypeInfos.size();
		Assert.areEqual(expected, recordTypes.size(), 'Record type count should match describe');
	}
}