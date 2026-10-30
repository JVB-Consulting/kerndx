// SPDX-License-Identifier: Apache-2.0
public with sharing class KernUseTestBuilder_NegativeProduction
{
	public static Account buildAccount()
	{
		return new Account(Name = 'Acme');
	}
}
