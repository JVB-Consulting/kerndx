// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_RecordType selector.
 *
 * @see SEL_RecordType
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_RecordType_TEST
{
	/**
	 * @description Tests that findByObjectType executes without error.
	 */
	@IsTest
	private static void shouldFindByObjectType()
	{
		List<RecordType> results = new SEL_RecordType().findByObjectType(Account.SObjectType);

		Assert.isNotNull(results, 'Should return a list');
	}

	/**
	 * @description Tests that personAccountRecordTypes lazy property loads without error.
	 */
	@IsTest
	private static void shouldLoadPersonAccountRecordTypes()
	{
		Set<Id> results = SEL_RecordType.personAccountRecordTypes;

		Assert.isNotNull(results, 'Should return a set');
	}
}