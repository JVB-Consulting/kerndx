// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {executeAnonymousApex, soqlQuery} = require('../helpers/sf-cli');

const MAX_POLL_SECONDS = 30;
const POLL_INTERVAL_MS = 2000;

/**
 * Polls until the chain reaches a terminal status or times out.
 * @param {string} executionId - The AsyncChainExecution__c record ID.
 * @param {import('@playwright/test').Page} page - Playwright page for waitForTimeout.
 * @param {import('@playwright/test').TestInfo} testInfo - For annotations.
 * @returns {Promise<string>} The terminal status.
 */
async function pollUntilTerminal(executionId, page, testInfo)
{
	const maxAttempts = Math.ceil((MAX_POLL_SECONDS * 1000) / POLL_INTERVAL_MS);
	let status = 'Running';

	for(let attempt = 1; attempt <= maxAttempts && status === 'Running'; attempt++)
	{
		await page.waitForTimeout(POLL_INTERVAL_MS);
		const records = soqlQuery(
				`SELECT kern__Status__c FROM kern__AsyncChainExecution__c WHERE Id = '${executionId}'`
		);
		expect(records.length, 'Execution record should exist').toBe(1);
		status = records[0].kern__Status__c;
		testInfo.annotations.push({type: 'notes', description: `Poll ${attempt}/${maxAttempts}: ${status}`});
	}

	expect(status, `Chain ${executionId} should reach terminal status within ${MAX_POLL_SECONDS}s`).not.toBe('Running');
	return status;
}

/**
 * Launches a chain via anonymous Apex and returns the execution ID.
 * @param {string} apex - Anonymous Apex that outputs CHAIN_ID:<id>.
 * @returns {string} The chain execution ID.
 */
function launchChain(apex)
{
	const output = executeAnonymousApex(apex);
	const match = output.match(/CHAIN_ID:([a-zA-Z0-9]{15,18})/);
	expect(match, 'Should capture chain execution ID from Apex output').toBeTruthy();
	return match[1];
}

test.describe.serial('Part 7: Async Chain Orchestration', () =>
{
	let chainExecutionId;

	test('V10: Execute async chain and verify execution record created', async({page}, testInfo) =>
	{
		chainExecutionId = launchChain(`
			String executionId = kern.UTIL_AsyncChain.newChain('E2E_OnboardingChain')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.execute();
			System.debug('CHAIN_ID:' + executionId);
		`);
		testInfo.annotations.push({type: 'notes', description: `Chain execution ID: ${chainExecutionId}`});
	});

	test('V11: Chain execution completes asynchronously', async({page}, testInfo) =>
	{
		const status = await pollUntilTerminal(chainExecutionId, page, testInfo);
		expect(status, 'Chain should complete successfully').toBe('Completed');
	});

	test('V12: Verify all execution record fields', async({page}, testInfo) =>
	{
		const records = soqlQuery(
				`SELECT Name, kern__ChainName__c, kern__Status__c, kern__TotalSteps__c, kern__CompletedSteps__c,
						kern__CorrelationId__c, kern__StartedAt__c, kern__CompletedAt__c, kern__ContextData__c,
						kern__CurrentStepName__c, kern__StepLog__c, kern__ErrorMessage__c
				FROM kern__AsyncChainExecution__c WHERE Id = '${chainExecutionId}'`
		);
		expect(records.length).toBe(1);

		const execution = records[0];

		// Name (AutoNumber)
		expect(execution.Name, 'Name should be auto-numbered').toMatch(/^CHAIN-\d+$/);

		// ChainName__c
		expect(execution.kern__ChainName__c, 'ChainName should match').toBe('E2E_OnboardingChain');

		// Status__c
		expect(execution.kern__Status__c, 'Status should be Completed').toBe('Completed');

		// TotalSteps__c / CompletedSteps__c
		expect(execution.kern__TotalSteps__c, 'TotalSteps should be 2').toBe(2);
		expect(execution.kern__CompletedSteps__c, 'CompletedSteps should equal TotalSteps').toBe(2);

		// CorrelationId__c (UUID format)
		expect(execution.kern__CorrelationId__c, 'CorrelationId should be populated').toBeTruthy();
		expect(execution.kern__CorrelationId__c.length, 'CorrelationId should be UUID length').toBeGreaterThanOrEqual(36);

		// StartedAt__c / CompletedAt__c
		expect(execution.kern__StartedAt__c, 'StartedAt should be set').toBeTruthy();
		expect(execution.kern__CompletedAt__c, 'CompletedAt should be set').toBeTruthy();

		// CurrentStepName__c — should reflect the last step executed
		expect(execution.kern__CurrentStepName__c, 'CurrentStepName should be populated').toBeTruthy();

		// StepLog__c — JSON array of step log entries with runtime results
		expect(execution.kern__StepLog__c, 'StepLog should be populated').toBeTruthy();
		const stepLog = JSON.parse(execution.kern__StepLog__c);
		expect(Array.isArray(stepLog), 'StepLog should be a JSON array').toBeTruthy();
		expect(stepLog.length, 'StepLog should have 2 entries').toBe(2);
		expect(stepLog[0].className, 'First step should have a className').toBeTruthy();
		expect(stepLog[0].success, 'First step should have success=true').toBe(true);
		expect(stepLog[0].durationMs, 'First step should have durationMs').toBeDefined();

		// ContextData__c — serialized context map
		expect(execution.kern__ContextData__c, 'ContextData should be populated').toBeTruthy();
		const context = JSON.parse(execution.kern__ContextData__c);
		expect(context.foobarId, 'Context should contain foobarId').toBeTruthy();

		// ErrorMessage__c — should be null on success
		expect(execution.kern__ErrorMessage__c, 'ErrorMessage should be null on successful chain').toBeNull();

		testInfo.annotations.push({type: 'notes', description: `${execution.Name}: ${execution.kern__CompletedSteps__c}/${execution.kern__TotalSteps__c} steps, correlation=${execution.kern__CorrelationId__c}`});
	});

	test('V13: AsyncChainExecution tab visible in Kern app', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		await waitForPageLoad(page);

		const nav = page.locator('one-app-nav-bar');
		const tabs = await nav.locator('one-app-nav-bar-item-root').allInnerTexts();
		const hasChainTab = tabs.some(t => t.includes('Async Chain Executions'));
		expect(hasChainTab, 'Async Chain Executions tab should be visible in Kern app').toBeTruthy();
	});

	test('V14: Navigate to execution record page', async({page}) =>
	{
		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__AsyncChainExecution__c/${chainExecutionId}/view`,
				{waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);

		const recordPage = page.locator('records-record-layout-event-broker, records-lwc-detail-panel').first();
		await expect(recordPage).toBeVisible({timeout: 15_000});

		const pageContent = await page.content();
		expect(pageContent, 'Record page should contain chain name').toContain('E2E_OnboardingChain');
	});

	test('V15: Execute failing chain and verify Failed status', async({page}, testInfo) =>
	{
		const failedId = launchChain(`
			String executionId = kern.UTIL_AsyncChain.newChain('E2E_FailingChain')
					.then(new SubscriberChainSteps.FailingStep())
					.execute();
			System.debug('CHAIN_ID:' + executionId);
		`);

		const status = await pollUntilTerminal(failedId, page, testInfo);
		expect(status).toBe('Failed');

		const records = soqlQuery(
				`SELECT kern__ErrorMessage__c FROM kern__AsyncChainExecution__c WHERE Id = '${failedId}'`
		);
		expect(records[0].kern__ErrorMessage__c).toContain('Deliberate subscriber failure');
	});

	test('V16: Full 4-step chain with DML, API callout, and verification', async({page}, testInfo) =>
	{
		const apiChainId = launchChain(`
			String executionId = kern.UTIL_AsyncChain.newChain('E2E_FullChain')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.then(new SubscriberChainSteps.CallApiStep())
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.then(new SubscriberChainSteps.VerifyContextStep())
					.execute();
			System.debug('CHAIN_ID:' + executionId);
		`);

		const status = await pollUntilTerminal(apiChainId, page, testInfo);
		expect(status, '4-step chain should complete').toBe('Completed');

		const records = soqlQuery(
				`SELECT kern__CompletedSteps__c, kern__TotalSteps__c, kern__ContextData__c,
						kern__CurrentStepName__c, kern__ErrorMessage__c
				FROM kern__AsyncChainExecution__c WHERE Id = '${apiChainId}'`
		);
		const execution = records[0];
		expect(execution.kern__TotalSteps__c, 'Should have 4 total steps').toBe(4);
		expect(execution.kern__CompletedSteps__c, 'All 4 steps should complete').toBe(4);
		expect(execution.kern__ErrorMessage__c, 'No error on success').toBeNull();

		const context = JSON.parse(execution.kern__ContextData__c);
		expect(context.foobarId, 'CreateFoobarStep should set foobarId').toBeTruthy();
		expect(context.apiResponse, 'CallApiStep should set apiResponse').toBe('invoked');
		expect(context.verified, 'VerifyContextStep should confirm all context valid').toBe(true);

		testInfo.annotations.push({type: 'notes', description: `4-step chain: DML → API → Update → Verify, all fields validated`});
	});

	test('V17: Handler callout isolation — onComplete callout after DML step', async({page}, testInfo) =>
	{
		const handlerChainId = launchChain(`
			String executionId = kern.UTIL_AsyncChain.newChain('E2E_HandlerCallout')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.onComplete(new SubscriberChainSteps.CallApiStep())
					.execute();
			System.debug('CHAIN_ID:' + executionId);
		`);

		const status = await pollUntilTerminal(handlerChainId, page, testInfo);
		expect(status, 'Chain with DML step + callout handler should complete').toBe('Completed');

		const records = soqlQuery(
				`SELECT kern__ContextData__c FROM kern__AsyncChainExecution__c WHERE Id = '${handlerChainId}'`
		);
		const context = JSON.parse(records[0].kern__ContextData__c);
		expect(context.apiResponse, 'onComplete handler should have invoked API callout').toBe('invoked');

		testInfo.annotations.push({type: 'notes', description: 'Handler callout isolation verified: DML step → callout in onComplete handler'});
	});
});
