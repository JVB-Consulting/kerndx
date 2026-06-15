// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernSecurityBypassCallSite_positive
{
	public void exercise()
	{
		List<Account> accounts = new kern.QRY_Builder(Account.SObjectType).withSystemMode().toList();
		List<Account> shared = new kern.QRY_Builder(Account.SObjectType).bypassSharing().toList();
		List<Account> open = new kern.QRY_Builder(Account.SObjectType).withoutSecurity().toList();
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.UTIL_ValidationRule.bypassGroup('Sales_Account_Validations');
		kern.UTIL_ValidationRule.bypassRule('Account_Requires_Industry');
		kern.TRG_Base.bypassAction('TRG_SetAccountDefaults');
	}
}
