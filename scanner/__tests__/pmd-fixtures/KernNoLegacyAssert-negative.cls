// SPDX-License-Identifier: BUSL-1.1
@IsTest
private class KernNoLegacyAssertNegative
{
	@IsTest
	static void usesModernAsserts()
	{
		Integer answer = 42;
		Assert.isTrue(answer > 0, 'modern boolean assert');
		Assert.areEqual(42, answer, 'modern equality assert');
		Assert.areNotEqual(0, answer, 'modern inequality assert');
	}
}
