// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for Account validation rules.
 *
 * @author your.name@company.com
 *
 * @group Account Management
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class VAL_AccountRules_TEST
{
	/**
	 * @description Rule DeveloperName for the phone-or-website requirement.
	 */
	private static final String RULE_PHONE_OR_WEBSITE = 'PhoneOrWebsiteRequired';

	/**
	 * @description Rule DeveloperName for the missing website warning.
	 */
	private static final String RULE_WARN_MISSING_WEBSITE = 'WarnMissingWebsite';

	/**
	 * @description Tests that blank phone and website fails validation.
	 */
	@IsTest
	private static void shouldFailWhenBothPhoneAndWebsiteBlank()
	{
		Account record = new Account(Name = 'Test Corp');
		kern.UTIL_ValidationTestHelper.assertRuleFails(record, RULE_PHONE_OR_WEBSITE);
	}

	/**
	 * @description Tests that populated phone passes phone-or-website rule.
	 */
	@IsTest
	private static void shouldPassPhoneOrWebsiteWhenPhonePopulated()
	{
		Account record = new Account(Name = 'Test Corp', Phone = '1234567890');
		kern.UTIL_ValidationTestHelper.assertRulePasses(record, RULE_PHONE_OR_WEBSITE);
	}

	/**
	 * @description Tests that populated website passes phone-or-website rule.
	 */
	@IsTest
	private static void shouldPassPhoneOrWebsiteWhenWebsitePopulated()
	{
		Account record = new Account(Name = 'Test Corp', Website = 'https://example.com');
		kern.UTIL_ValidationTestHelper.assertRulePasses(record, RULE_PHONE_OR_WEBSITE);
	}

	/**
	 * @description Tests that missing website triggers the warning rule.
	 */
	@IsTest
	private static void shouldWarnWhenWebsiteMissing()
	{
		Account record = new Account(Name = 'Test Corp', Phone = '1234567890');
		kern.UTIL_ValidationTestHelper.assertRuleFails(record, RULE_WARN_MISSING_WEBSITE);
	}

	/**
	 * @description Tests that populated website passes the warning rule.
	 */
	@IsTest
	private static void shouldPassWebsiteWarningWhenWebsitePopulated()
	{
		Account record = new Account(Name = 'Test Corp', Website = 'https://example.com');
		kern.UTIL_ValidationTestHelper.assertRulePasses(record, RULE_WARN_MISSING_WEBSITE);
	}
}
