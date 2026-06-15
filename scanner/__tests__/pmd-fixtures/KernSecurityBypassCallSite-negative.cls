// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernSecurityBypassCallSite_negative
{
	public void exercise()
	{
		List<Account> accounts = new kern.QRY_Builder(Account.SObjectType).withUserMode().toList();
		kern.UTIL_ValidationRule.clearAllBypasses();
		Boolean processed = bypassSharingCheckCompleted();
	}

	private Boolean bypassSharingCheckCompleted()
	{
		return true;
	}
}
