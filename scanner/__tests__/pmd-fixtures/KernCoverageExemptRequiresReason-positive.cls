// SPDX-License-Identifier: Apache-2.0
@IsTest(SeeAllData=false IsParallel=true)
private class KernCoverageExemptRequiresReason_Positive_TEST
{
	@IsTest
	@SuppressWarnings('PMD.KernNoCoverageTheatre')
	private static void shouldSilenceTheatreWithoutReason()
	{
		String value = 'no assertion, suppressed';
		value += value;
	}
}
