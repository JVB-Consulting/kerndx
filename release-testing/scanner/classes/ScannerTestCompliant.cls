// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Compliant class that should produce ZERO KernDX violations.
 * Uses all framework patterns correctly.
 */
public with sharing class ScannerTestCompliant
{
	/**
	 * @description Demonstrates compliant query via QRY_Builder.
	 */
	public void compliantQuery()
	{
		List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.condition(Account.Name).equals('Test')
				.toList();
	}

	/**
	 * @description Demonstrates compliant DML via DML_Builder.
	 */
	public void compliantDml()
	{
		Account account = new Account(Name = 'Test');
		DML_Builder.newTransaction().doInsert(Account).execute();
	}

	/**
	 * @description Demonstrates compliant logging via LOG_Builder.
	 */
	public void compliantLogging()
	{
		LOG_Builder.build().info('Compliant logging').emitAt('ScannerTestCompliant.compliantLogging');
	}

	/**
	 * @description Demonstrates compliant HTTP via UTIL_HttpClient.
	 */
	public void compliantHttp()
	{
		UTIL_HttpClient.get('NamedCredential', '/api/test').send();
	}
}
