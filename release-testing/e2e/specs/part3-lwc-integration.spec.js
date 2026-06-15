// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const SubscriberLwcTestPage = require('../pages/subscriber-lwc-test.page');
const {soqlQuery, executeAnonymousApex, deleteRecord} = require('../helpers/sf-cli');

test.describe.serial('Part 3: Subscriber LWC & Account Integration', () =>
{
	const accountName = `E2E Test Account ${Date.now()}`;
	let accountId;

	test('V11: Subscriber LWC Test Page — Components', async({page}) =>
	{
		const lwcPage = new SubscriberLwcTestPage(page);
		await lwcPage.navigate();

		const allVisible = await lwcPage.allComponentsVisible();
		expect(allVisible, `All ${SubscriberLwcTestPage.EXPECTED_COMPONENTS.length} components should be visible`).toBeTruthy();

		const hasErrors = await lwcPage.hasErrorBoundaries();
		expect(hasErrors, 'Should have no error boundaries').toBeFalsy();
	});

	test('V12: Subscriber LWC Interactions', async({page}) =>
	{
		const lwcPage = new SubscriberLwcTestPage(page);
		await lwcPage.navigate();

		for(const section of SubscriberLwcTestPage.MODULE_SECTIONS)
		{
			const result = await lwcPage.runAndVerifySection(section);
			test.info().annotations.push({type: 'notes', description: `${section}: ${result.passed}/${result.total} passed`});
			expect(result.failed, `${section} should have all tests passing. Failures: ${result.failures.join(', ')}`).toBe(0);
		}

		const EXPECTED_FAILURES = ['failOnPurpose: FAIL'];

		for(const section of SubscriberLwcTestPage.INTEGRATION_SECTIONS)
		{
			const result = await lwcPage.runAndVerifySection(section);
			test.info().annotations.push({type: 'notes', description: `${section}: ${result.passed}/${result.total} passed`});
			const unexpected = result.failures.filter(f => !EXPECTED_FAILURES.includes(f));
			expect(unexpected.length, `${section} has unexpected failures: ${unexpected.join(', ')}`).toBe(0);
		}
	});

	test('V13: Account Creation Integration', async() =>
	{
		executeAnonymousApex(
				`kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow'); Account a = new Account(Name = '${accountName}', Industry = 'Technology', Phone = '555-0100'); insert a; System.debug(a.Id);`);
		const created = soqlQuery(`SELECT Id, Description
                                   FROM Account
                                   WHERE Name = '${accountName}' LIMIT 1`);
		expect(created.length, 'Account should be created').toBe(1);
		accountId = created[0].Id;
		expect(created[0].Description, 'Description should be set by TRG_SetAccountDefaults').toBe('Default');

		const tasks = soqlQuery(`SELECT Id, Subject
                                 FROM Task
                                 WHERE WhatId = '${accountId}'`);
		expect(tasks.length, 'Task should be created by TRG_CreateAccountTask').toBeGreaterThan(0);
		expect(tasks[0].Subject).toContain('Review New Account');
	});

	test('V14: Account Integration — Log Entries', async() =>
	{
		const logs = soqlQuery('SELECT Id, kern__LogLevel__c, kern__Message__c FROM kern__LogEntry__c WHERE kern__LogLevel__c = \'WARN\' ORDER BY CreatedDate DESC LIMIT 10');
		expect(logs.length, 'WARN log entries should exist from WarnMissingWebsite').toBeGreaterThan(0);

		if(accountId)
		{
			deleteRecord('Account', accountId);
		}
	});
});
