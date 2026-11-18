// SPDX-License-Identifier: Apache-2.0
/**
 * @description One step of a background job, used by the "From Plain Apex to KernDX" page. It finds the Technology
 * accounts and writes a note into their description. The page shows this code as it is, so the values are written out.
 *
 * A step extends kern.UTIL_AsyncChain.ChainStep and puts its work in work(). The class is global and declares no
 * constructor, because the framework creates the step from its class name each time it runs.
 *
 * @see DocumentationSamples_TEST
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date October 2026
 */
global inherited sharing class EnrichTechnologyAccountsStep extends kern.UTIL_AsyncChain.ChainStep
{
	/**
	 * @description Finds the Technology accounts, writes the note into their description and saves them.
	 *
	 * @param context The values shared by all steps of the job. This step does not read it.
	 *
	 * @return A result that says the step worked.
	 */
	global override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
	{
		List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Id})
				.condition(Account.Industry).equals('Technology')
				.toList();

		for(Account account : accounts)
		{
			account.Description = 'Enriched in the background';
		}

		kern.DML_Builder.newTransaction().doUpdate(accounts).execute();

		return kern.UTIL_AsyncChain.succeeded();
	}
}
