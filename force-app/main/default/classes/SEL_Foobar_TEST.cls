// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_Foobar selector.
 *
 * @see SEL_Foobar
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_Foobar_TEST
{
	/**
	 * @description Tests that getAll returns records in a test context.
	 */
	@IsTest
	private static void shouldGetAll()
	{
		TST_Factory.insertFoobar();

		List<Foobar__c> results = new SEL_Foobar().getAll();

		Assert.isFalse(results.isEmpty(), 'Should return records in test context');
	}

	/**
	 * @description Tests that findByParentId returns child records with parent relationship fields populated.
	 */
	@IsTest
	private static void shouldFindByParentId()
	{
		Foobar__c parent = TST_Factory.insertFoobar();

		TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Lookup__c, parent.Id)
				.build();

		List<Foobar__c> results = new SEL_Foobar().findByParentId(parent.Id);

		Assert.areEqual(1, results.size(), 'Should return child record');
		Assert.isNotNull(results[0].Lookup__r.Name, 'Should include parent relationship name from getFieldPaths');
	}

	/**
	 * @description Tests that findByParentId returns an empty list when no children exist.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenNoChildren()
	{
		Foobar__c parent = TST_Factory.insertFoobar();

		List<Foobar__c> results = new SEL_Foobar().findByParentId(parent.Id);

		Assert.isTrue(results.isEmpty(), 'Should return empty list when no children exist');
	}
}