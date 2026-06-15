// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_E2E_DEMO. Validates the processData method at 100%
 * coverage across the standard, blank-input, and whitespace-only paths.
 *
 * @see FastStart_E2E_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_E2E_DEMO_TEST
{
	/**
	 * @description Standard input used across happy-path tests.
	 */
	private static final String INPUT_STANDARD = 'hello world';

	/**
	 * @description Expected output for the standard input.
	 */
	private static final String EXPECTED_STANDARD = 'PROCESSED: HELLO WORLD';

	/**
	 * @description Input with leading and trailing whitespace.
	 */
	private static final String INPUT_PADDED = '  hello world  ';

	/**
	 * @description Verifies that a non-blank input is trimmed, uppercased, and prefixed correctly.
	 */
	@IsTest
	private static void shouldProcessStandardInput()
	{
		String result = new FastStart_E2E_DEMO().processData(INPUT_STANDARD);

		Assert.areEqual(EXPECTED_STANDARD, result, 'Standard input should be uppercased and prefixed');
	}

	/**
	 * @description Verifies that surrounding whitespace is stripped before transformation.
	 */
	@IsTest
	private static void shouldTrimBeforeProcessing()
	{
		String result = new FastStart_E2E_DEMO().processData(INPUT_PADDED);

		Assert.areEqual(EXPECTED_STANDARD, result, 'Padded input should produce the same result as trimmed input');
	}

	/**
	 * @description Verifies that blank input (null, empty string, whitespace-only) returns an
	 * empty string rather than a prefixed blank value.
	 */
	@IsTest
	private static void shouldReturnEmptyStringForBlankInput()
	{
		FastStart_E2E_DEMO demo = new FastStart_E2E_DEMO();

		Assert.areEqual('', demo.processData(null), 'Null input should return empty string');
		Assert.areEqual('', demo.processData(''), 'Empty input should return empty string');
		Assert.areEqual('', demo.processData('   '), 'Whitespace-only input should return empty string');
	}
}
