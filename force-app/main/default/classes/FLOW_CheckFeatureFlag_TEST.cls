// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Will test the behaviour of FLOW_CheckFeatureFlag.
 * This test validates that the invocable action correctly processes the list of
 * flag names and returns a corresponding list of boolean statuses.
 *
 * @see FLOW_CheckFeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date November 2025, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class FLOW_CheckFeatureFlag_TEST
{
	/**
	 * @description Tests that the action processes a list of mixed-value flags
	 * and returns the results in the correct order.
	 */
	@IsTest
	private static void flagListProcessing()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;

		List<String> flagNames = new List<String>
		{
				SEL_FeatureFlag.TEST_FEATURE_FLAG,
				UTIL_Random.randomName()
		};

		Test.startTest();

		List<Boolean> results = FLOW_CheckFeatureFlag.isEnabled(flagNames);

		Test.stopTest();

		// Assert
		Assert.areEqual(flagNames.size(), results.size(), 'Result list size should match input list size.');

		Assert.isTrue(results[0], 'Flag should be true.');
		Assert.isFalse(results[1], 'Flag should be false.');
	}
}