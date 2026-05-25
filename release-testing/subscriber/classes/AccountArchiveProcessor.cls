// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Processes Account records for archival.
 *
 * @see AccountArchiveProcessor_TEST
 *
 * @author your.name@company.com
 *
 * @group Account Management
 *
 * @date February 2026, May 2026
 */
public with sharing class AccountArchiveProcessor implements kern.IF_Async.Processable
{
	/**
	 * @description Description value set on archived records.
	 */
	@TestVisible private static final String DESCRIPTION_ARCHIVED = 'Archived';

	/**
	 * @description Marks each account as archived.
	 *
	 * @param items Records to process (cast from Object individually).
	 */
	public void execute(List<Object> items)
	{
		List<Account> records = new List<Account>();

		for(Object item : items)
		{
			records.add((Account)item);
		}

		for(Account record : records)
		{
			record.Description = DESCRIPTION_ARCHIVED;
		}

		kern.DML_Builder.newTransaction()
				.doUpdate(records)
				.allowPartial()
				.execute();
	}
}
