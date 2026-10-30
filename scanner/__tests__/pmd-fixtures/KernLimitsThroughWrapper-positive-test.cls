// SPDX-License-Identifier: Apache-2.0
@IsTest(SeeAllData=false IsParallel=true)
private class KernLimitsThroughWrapperPositive_TEST
{
	@IsTest
	private static void shouldReadLimitsDirectlyOutsideTheWrapperTest()
	{
		Integer queriesBefore = Limits.getQueries();
		Assert.areEqual(0, queriesBefore, 'no query has run yet');
	}
}
