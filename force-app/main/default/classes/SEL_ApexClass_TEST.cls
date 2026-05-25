// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for SEL_ApexClass selector methods.
 *
 * @see SEL_ApexClass
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SEL_ApexClass_TEST
{
	/**
	 * @description Tests that findSchedulableClassNames returns known Schedulable classes.
	 */
	@IsTest
	private static void shouldReturnSchedulableClassNames()
	{
		List<String> classNames = new SEL_ApexClass().findSchedulableClassNames();

		Assert.isFalse(classNames.isEmpty(), 'Should return at least one Schedulable class');
		Assert.isTrue(classNames.contains(SCHED_DeactivateUsers.class.getName()), 'Should contain SCHED_DeactivateUsers');
	}

	/**
	 * @description Tests that getFields returns Name and NamespacePrefix.
	 */
	@IsTest
	private static void shouldReturnDefaultFields()
	{
		List<SObjectField> fields = new SEL_ApexClass().getFields();

		Assert.areEqual(2, fields.size(), 'Should return two fields');
		Assert.isTrue(fields.contains(ApexClass.Name), 'Should contain Name field');
		Assert.isTrue(fields.contains(ApexClass.NamespacePrefix), 'Should contain NamespacePrefix field');
	}
}