// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_FeatureFlag selector.
 *
 * @see SEL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_FeatureFlag_TEST
{
	/**
	 * @description Tests that allDeveloperNames returns a non-null set of feature flag developer names.
	 */
	@IsTest
	private static void shouldReturnAllDeveloperNames()
	{
		Set<String> result = SEL_FeatureFlag.allDeveloperNames;

		Assert.isNotNull(result, 'Should return developer names set');
	}

	/**
	 * @description Tests that activeFlags returns a non-null map of active feature flags.
	 */
	@IsTest
	private static void shouldReturnActiveFlags()
	{
		Map<String, FeatureFlag__mdt> result = SEL_FeatureFlag.activeFlags;

		Assert.isNotNull(result, 'Should return active flags map');
	}

	/**
	 * @description Tests that the constructor initializes correctly and getFields returns expected fields.
	 *
	 * @see SEL_FeatureFlag.getFields
	 */
	@IsTest
	private static void shouldReturnDefaultFields()
	{
		SEL_FeatureFlag selector = new SEL_FeatureFlag();

		List<SObjectField> fields = selector.getFields();

		Assert.isFalse(fields.isEmpty(), 'Should return default fields');
		Assert.isTrue(fields.contains(FeatureFlag__mdt.DeveloperName), 'Should contain DeveloperName');
	}
}