// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate violation — @RestResource class not named REST_*.
 * Used to validate KernRestResourceNaming rule.
 *
 * Expected violations:
 * - KernRestResourceNaming (x1: @RestResource on non-REST_* class)
 */
@RestResource(UrlMapping='/test/scanner/*')
public with sharing class ScannerTestRestViolation
{
	/**
	 * @description Test GET endpoint.
	 */
	@HttpGet
	public static void doGet()
	{
	}
}
