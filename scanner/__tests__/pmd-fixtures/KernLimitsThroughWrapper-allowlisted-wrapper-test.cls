// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_Limits_TEST
{
	@IsTest
	private static void shouldMatchThePlatformQueryCount()
	{
		Assert.areEqual(Limits.getQueries(), UTIL_Limits.soqlQueries().used(), 'the wrapper reads the platform counter');
	}
}
