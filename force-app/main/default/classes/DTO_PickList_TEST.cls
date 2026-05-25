// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for DTO_PickList.
 *
 * @see DTO_PickList
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class DTO_PickList_TEST
{
	/**
	 * @description Tests that all fields can be populated and accessed.
	 */
	@IsTest
	private static void shouldPopulateAllFields()
	{
		DTO_PicklistValue defaultPicklistValue = new DTO_PicklistValue();
		defaultPicklistValue.label = 'Default';
		defaultPicklistValue.value = 'default';

		DTO_PicklistValue picklistValue = new DTO_PicklistValue();
		picklistValue.label = 'Option';
		picklistValue.value = 'option';
		picklistValue.validFor = new List<String> {'Controlling'};

		DTO_PickList dto = new DTO_PickList();

		dto.picklistName = 'Status__c';
		dto.defaultValue = defaultPicklistValue;
		dto.values = new List<DTO_PicklistValue> {picklistValue};

		Assert.areEqual('Status__c', dto.picklistName, 'picklistName should be set');
		Assert.isNotNull(dto.defaultValue, 'defaultValue should be set');
		Assert.areEqual(1, dto.values.size(), 'values should contain one entry');
	}
}