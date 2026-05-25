// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernCoverageExemptRequiresReason_Negative_TEST
{
	@IsTest
	private static void shouldNotSuppressTheatreRule()
	{
		Assert.isTrue(true, 'plain compliant test');
	}
}
