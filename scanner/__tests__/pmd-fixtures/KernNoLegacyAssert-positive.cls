// SPDX-License-Identifier: BUSL-1.1
@IsTest
private class KernNoLegacyAssertPositive
{
	@IsTest
	static void usesLegacyAsserts()
	{
		Integer answer = 42;
		System.assert(answer > 0, 'legacy boolean assert');
		System.assertEquals(42, answer, 'legacy equality assert');
		System.assertNotEquals(0, answer, 'legacy inequality assert');
	}
}
