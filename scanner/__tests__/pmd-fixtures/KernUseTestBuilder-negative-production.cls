// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernUseTestBuilder_NegativeProduction
{
	public static Account buildAccount()
	{
		return new Account(Name = 'Acme');
	}
}
