// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Demo class for the Fast Start - E2E Testing guide. Provides a simple
 * data-processing method that subscriber Apex tests can exercise without any DML or SObject
 * construction — keeping the example pure and fast.
 *
 * @see FastStart_E2E_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_E2E_DEMO
{
	/**
	 * @description Returns a transformed version of the input string: trimmed, uppercased, and
	 * prefixed with "PROCESSED: ". Returns an empty string when the input is blank.
	 *
	 * @param input The raw string to process.
	 *
	 * @return The processed result, or an empty string when input is blank.
	 */
	public String processData(String input)
	{
		if(String.isBlank(input))
		{
			return '';
		}

		return 'PROCESSED: ' + input.trim().toUpperCase();
	}
}
