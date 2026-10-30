// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for SEL_FeatureFlagStrategy selector.
 *
 * @see SEL_FeatureFlagStrategy
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_FeatureFlagStrategy_TEST
{
	/**
	 * @description Tests that getFields returns the expected number of fields.
	 */
	@IsTest
	private static void shouldReturnExpectedFields()
	{
		List<SObjectField> result = new SEL_FeatureFlagStrategy().getFields();

		Assert.areEqual(8, result.size(), 'Should return 8 fields');
	}
}