// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for DTO_NameValue.
 *
 * @see DTO_NameValue
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class DTO_NameValue_TEST
{
	/**
	 * @description Tests that all fields can be populated and accessed.
	 */
	@IsTest
	private static void shouldPopulateAllFields()
	{
		DTO_NameValue dto = new DTO_NameValue();

		dto.name = 'MergeField';
		dto.value = 'Hello World';

		Assert.areEqual('MergeField', dto.name, 'name should be set');
		Assert.areEqual('Hello World', dto.value, 'value should be set');
	}

	/**
	 * @description Tests the convenience constructor that accepts name and value.
	 */
	@IsTest
	private static void shouldConstructWithNameAndValue()
	{
		DTO_NameValue dto = new DTO_NameValue('Recipient', 'user@example.com');

		Assert.areEqual('Recipient', dto.name, 'name should be set via constructor');
		Assert.areEqual('user@example.com', dto.value, 'value should be set via constructor');
	}
}