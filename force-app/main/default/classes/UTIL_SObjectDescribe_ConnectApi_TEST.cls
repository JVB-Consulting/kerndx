// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for ConnectApi-dependent methods in UTIL_SObjectDescribe.
 * Separated from UTIL_SObjectDescribe_TEST because ConnectApi requires SeeAllData=true.
 *
 * @see UTIL_SObjectDescribe
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestShouldNotUseSeeAllDataTrue')
private class UTIL_SObjectDescribe_ConnectApi_TEST
{
	/**
	 * @description The object API name used for testing picklist retrieval.
	 */
	private static final String TEST_OBJECT_NAME = SEL_Foobar.OBJECT_NAME;

	/**
	 * @description The record type developer name used for testing picklist retrieval.
	 */
	private static final String TEST_RECORD_TYPE = SEL_Foobar.RT_DEFAULT;

	/**
	 * @description Tests that getPicklistValuesByRecordType returns a valid collection
	 * for a known object and record type.
	 */
	@IsTest
	private static void shouldReturnPicklistValuesForRecordType()
	{
		TST_Factory.assignAdministratorPermissionSet();

		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			Id recordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(UTIL_SObjectDescribe.getSObjectTypeByName(TEST_OBJECT_NAME), TEST_RECORD_TYPE);

			ConnectApi.PicklistValuesCollection result = UTIL_SObjectDescribe.getPicklistValuesByRecordType(TEST_OBJECT_NAME, recordTypeId);

			Assert.isNotNull(result, 'Should return a non-null collection');
			Assert.isNotNull(result.picklistFieldValues, 'Should contain picklist field values');
			Assert.isFalse(result.picklistFieldValues.isEmpty(), 'Should contain at least one picklist field');
		}
	}

	/**
	 * @description Tests that getPicklistValues returns transformed DTO_PickList objects
	 * for a known object and record type.
	 */
	@IsTest
	private static void shouldReturnTransformedPicklistValues()
	{
		TST_Factory.assignAdministratorPermissionSet();

		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			Id recordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(UTIL_SObjectDescribe.getSObjectTypeByName(TEST_OBJECT_NAME), TEST_RECORD_TYPE);

			List<DTO_PickList> result = UTIL_SObjectDescribe.getPicklistValues(TEST_OBJECT_NAME, recordTypeId);

			Assert.isNotNull(result, 'Should return a non-null list');
			Assert.isFalse(result.isEmpty(), 'Should contain at least one picklist');

			DTO_PickList firstPicklist = result.iterator().next();
			Assert.isNotNull(firstPicklist.picklistName, 'Picklist name should be populated');
			Assert.isNotNull(firstPicklist.values, 'Picklist values should be populated');
		}
	}

	/**
	 * @description Tests that transformPicklistCollection returns an empty list when picklistFieldValues is null.
	 */
	@IsTest
	private static void shouldReturnEmptyListWhenPicklistFieldValuesNull()
	{
		ConnectApi.PicklistValuesCollection collection = new ConnectApi.PicklistValuesCollection();
		collection.picklistFieldValues = null;

		List<DTO_PickList> result = UTIL_SObjectDescribe.transformPicklistCollection(collection);

		Assert.isTrue(result.isEmpty(), 'Should return empty list for null picklistFieldValues');
	}

	/**
	 * @description Tests that buildControllerValueList returns an index-ordered list from a populated map.
	 */
	@IsTest
	private static void shouldBuildControllerValueListFromPopulatedMap()
	{
		Map<String, Integer> controllerValuesMap = new Map<String, Integer>
		{
				'Hot' => 0,
				'Warm' => 1,
				'Cold' => 2
		};

		List<String> result = UTIL_SObjectDescribe.buildControllerValueList(controllerValuesMap);

		Assert.areEqual(3, result.size(), 'Should have 3 controller values');
		Assert.areEqual('Hot', result[0], 'First value should be Hot');
		Assert.areEqual('Warm', result[1], 'Second value should be Warm');
		Assert.areEqual('Cold', result[2], 'Third value should be Cold');
	}

	/**
	 * @description Tests that transformPicklistValue maps validFor indexes to controller value labels.
	 */
	@IsTest
	private static void shouldTransformPicklistValueWithValidFor()
	{
		ConnectApi.PicklistValue sourceValue = new ConnectApi.PicklistValue();
		sourceValue.label = 'Sydney';
		sourceValue.value = 'Sydney';
		sourceValue.validFor = new List<Integer> {0, 2};

		List<String> controllerValues = new List<String> {'Australia', 'USA', 'UK'};

		DTO_PicklistValue result = UTIL_SObjectDescribe.transformPicklistValue(sourceValue, controllerValues);

		Assert.areEqual('Sydney', result.label, 'Label should match');
		Assert.areEqual('Sydney', result.value, 'Value should match');
		Assert.areEqual(2, result.validFor.size(), 'Should have 2 validFor entries');
		Assert.areEqual('Australia', result.validFor[0], 'First validFor should be Australia');
		Assert.areEqual('UK', result.validFor[1], 'Second validFor should be UK');
	}

}