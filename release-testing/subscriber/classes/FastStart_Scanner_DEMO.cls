// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberately violating class for the Fast Start - Code Scanning guide.
 *
 * This class is used as a scanner target to demonstrate KernDX PMD rule violations. It is
 * intentionally non-compliant and must NOT be used as a coding example. Do not deploy it
 * to a production org.
 *
 * Violations present:
 *   - Inline SOQL: [SELECT Id FROM Account] (KernNoInlineSOQL)
 *   - System.debug() call (KernNoSystemDebug)
 *
 * @see docs/Fast Start - Code Scanning.md
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_Scanner_DEMO
{
	/**
	 * @description Fetches accounts using inline SOQL and logs the result with System.debug().
	 * Both patterns are banned by KernDX framework rules.
	 *
	 * @return The list of Account records retrieved via inline SOQL.
	 */
	public List<Account> getAccounts()
	{
		Account[] accounts = [SELECT Id, Name FROM Account LIMIT 10];

		System.debug(accounts);

		return accounts;
	}
}
