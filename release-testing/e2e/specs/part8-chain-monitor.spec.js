// SPDX-License-Identifier: BUSL-1.1
const path = require('path');
const {test, expect} = require('@playwright/test');
const ChainMonitorPage = require('../pages/chain-monitor.page');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {executeAnonymousApex, soqlQuery} = require('../helpers/sf-cli');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {namespacePrefix, apexNamespacePrefix} = require('../helpers/sf-namespace');
const {deployMetadataDir} = require('../../runner/cmdt-deployer');

// --- Operator-action fixtures (V116+): frozen copy of record from the PLAN-138 M0 spec ---
const CHAIN_STEPS_FIXTURE_DIR = path.join(__dirname, '..', 'fixtures', 'chain-steps');
const RETRY_SUCCESS_TOAST = 'Retry started. E2E_RetryRecovery resumes at its failed step.';
const RESTART_SUCCESS_TOAST = 'Restart started. E2E_RestartLineage is running again from step 1, and its new run is selected.';
const SUSPENDED_TOAST = 'Chain processing suspended.';
const RESUMED_TOAST = 'Chain processing resumed.';
const ENABLED_BADGE = 'Chains enabled';
const SUSPENDED_BADGE = 'Chains suspended';
const RETRY_NOT_IDEMPOTENT_TOOLTIP = 'The failed step does not declare itself safe to re-run, so retry is not available.';
const REDRIVE_SUSPENDED_REASON = 'Chain processing is suspended. Resume it before re-driving chains.';
const STREAM_TITLE = 'Live activity';
const CLEAR_STALLED_TOAST_PATTERN = /^2 stalled chains checked: (\d+) re-driven, (\d+) marked failed, (\d+) still waiting\.$/;
// V122: the three viewport widths the shipped header broke at, and the widest header the monitor
// renders — Retry from failed step · Restart from start · divider · View logs.
const HEADER_LAYOUT_WIDTHS = [
	1600,
	1280,
	1024
];
const HEADER_LAYOUT_VIEWPORT_HEIGHT = 900;
const RELAYOUT_SETTLE_MS = 1000;
const MINIMUM_HEADER_ACTIONS = 3;
// V123/V124: a term no seeded chain name can contain, and the stalled fixture whose run has no
// recorded duration — the row whose Duration cell used to be blank.
const NO_MATCH_SEARCH_TERM = 'zzzznomatchzzz';
const ELAPSED_FIXTURE_CHAIN = 'E2E_ElapsedDuration';
const COLUMN_COUNT = 5;

let operatorSetupDone = false;

// Object and field API names carry the package prefix only on the subscriber org.
function prefixed(apiName)
{
	return `${namespacePrefix()}${apiName}`;
}

// The dev-org fixture compiles unprefixed; the subscriber org uses the managed-referencing fixture.
function operatorStepsClass()
{
	return namespacePrefix() ? 'SubscriberChainSteps' : 'EndToEndChainSteps';
}

function ensureOperatorSetup()
{
	if(operatorSetupDone)
	{
		return;
	}
	if(!namespacePrefix())
	{
		const fixtureRows = soqlQuery('SELECT Id FROM ApexClass WHERE Name = \'EndToEndChainSteps\' LIMIT 1', {tooling: true});
		if(fixtureRows.length === 0)
		{
			deployMetadataDir(CHAIN_STEPS_FIXTURE_DIR);
		}
	}
	const namespaceClause = namespacePrefix() ? 'NamespacePrefix = \'kern\'' : 'NamespacePrefix = NULL';
	executeAnonymousApex(`
		List<PermissionSet> operatorSets = [SELECT Id FROM PermissionSet WHERE Name IN ('AsyncChainRedrive', 'AsyncChainKillSwitch') AND ${namespaceClause}];
		for(PermissionSet operatorSet : operatorSets)
		{
			if([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :operatorSet.Id] == 0)
			{
				insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = operatorSet.Id);
			}
		}
	`);
	operatorSetupDone = true;
}

function launchChain(chainName, builderCalls, stepClassName, options = {})
{
	// A launch transaction with an active log correlation is the designed correlated path: the
	// chain adopts it AND serializes it into the executor's log context, so the chain's own log
	// entries carry the correlation the stream seed reads by. A correlation-less launch mints a
	// chain UUID its logs never carry — raised at M4 as an engine gap (ChainBuilder line 2185
	// still serializes the no-argument context).
	const correlationStatement = options.withLogCorrelation ? `${apexNamespacePrefix()}LOG_Builder.startCorrelation();` : '';
	const output = executeAnonymousApex(`
		${correlationStatement}
		String executionId = ${apexNamespacePrefix()}UTIL_AsyncChain.newChain('${chainName}')${builderCalls}
				.then(new ${operatorStepsClass()}.${stepClassName}())
				.execute();
		System.debug('CHAIN_ID:' + executionId);
	`);
	const match = output.match(/CHAIN_ID:([a-zA-Z0-9]{15,18})/);
	expect(match, `Chain ${chainName} should launch`).toBeTruthy();
	return match[1];
}

async function waitForChainStatus(page, chainId, status, timeoutMs = 150_000)
{
	const startedAt = Date.now();
	for(;;)
	{
		const records = soqlQuery(`SELECT ${prefixed('Status__c')} FROM ${prefixed('AsyncChainExecution__c')} WHERE Id = '${chainId}'`);
		if(records.length > 0 && records[0][prefixed('Status__c')] === status)
		{
			return;
		}
		if(Date.now() - startedAt > timeoutMs)
		{
			throw new Error(`Chain ${chainId} did not reach ${status} within ${timeoutMs}ms`);
		}
		await page.waitForTimeout(2000);
	}
}

// The detail pane clips at its own edge, so "off the pane" is invisible rather than merely ugly —
// which is exactly how View logs disappeared at 1024. One pixel of tolerance absorbs sub-pixel
// layout rounding without letting a genuinely clipped control pass.
function expectBoxInside(box, container, message)
{
	expect(box, `${message}: the element should be laid out`).not.toBeNull();
	expect(box.x, message).toBeGreaterThanOrEqual(container.x - 1);
	expect(box.y, message).toBeGreaterThanOrEqual(container.y - 1);
	expect(box.x + box.width, message).toBeLessThanOrEqual(container.x + container.width + 1);
	expect(box.y + box.height, message).toBeLessThanOrEqual(container.y + container.height + 1);
}

function boxesOverlap(first, second)
{
	return first.x < second.x + second.width && first.x + first.width > second.x
			&& first.y < second.y + second.height && first.y + first.height > second.y;
}

// Re-measures the header at one viewport width: the toolbar row and every action on it must lie
// inside the detail pane and clear of the chain name. The three widths are the ones the 1.7.0-6
// header broke at — a three-line progress sliver, buttons over the name, View logs clipped away.
async function expectHeaderFitsPane(page, monitor, width)
{
	await page.setViewportSize({width, height: HEADER_LAYOUT_VIEWPORT_HEIGHT});
	await page.waitForTimeout(RELAYOUT_SETTLE_MS);

	const paneBox = await monitor.getDetailPanel().boundingBox();
	const nameBox = await monitor.getChainNameHeading().boundingBox();
	expectBoxInside(await monitor.getToolbarRow().boundingBox(), paneBox, `The toolbar row must stay inside the detail pane at ${width}`);

	const buttons = monitor.getToolbarButtons();
	const buttonCount = await buttons.count();
	expect(buttonCount, `The toolbar should carry every header action at ${width}`).toBeGreaterThanOrEqual(MINIMUM_HEADER_ACTIONS);

	for(let index = 0; index < buttonCount; index++)
	{
		const buttonBox = await buttons.nth(index).boundingBox();
		expectBoxInside(buttonBox, paneBox, `Toolbar button ${index} must not clip off the pane at ${width}`);
		expect(boxesOverlap(buttonBox, nameBox), `Toolbar button ${index} must not paint over the chain name at ${width}`).toBe(false);
	}
}

function resetChainProcessingSwitch()
{
	const switchObject = prefixed('AsyncChainRuntimeSwitch__c');
	executeAnonymousApex(`
		${switchObject} runtimeSwitch = ${switchObject}.getOrgDefaults();
		runtimeSwitch.${prefixed('ChainsEnabled__c')} = true;
		upsert runtimeSwitch;
	`);
}

test.describe.serial('Part 8: Chain Monitor UI', () =>
{
	let monitor;

	test('V30: Chain Monitor launcher card on Kern Home', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		await waitForPageLoad(page);

		const homeContent = await page.content();
		expect(homeContent, 'Kern Home should contain Chain Monitor launcher card').toContain('Chain Monitor');
	});

	test('V31: Chain Monitor page loads with split panel layout', async({page}) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		const listPanel = monitor.getListPanel();
		await expect(listPanel).toBeVisible({timeout: 15000});

		const datatable = monitor.getDatatable();
		await expect(datatable).toBeVisible({timeout: 10000});

		const pageLabel = await monitor.getPageLabel();
		expect(pageLabel, 'Should show page label').toMatch(/Page \d+ of \d+/);
	});

	test('V32: Chain Monitor shows executions with correct columns', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		const rowCount = await monitor.getRowCount();
		expect(rowCount, 'Should show chain executions from Part 7 tests').toBeGreaterThan(0);

		const headerText = await monitor.getDatatable().locator('thead').innerText();
		expect(headerText, 'Should have Chain Name column').toContain('Chain Name');
		expect(headerText, 'Should have Status column').toContain('Status');
		expect(headerText, 'Should have Progress column').toContain('Progress');
		expect(headerText, 'Should have Started column').toContain('Started');
		expect(headerText, 'Should have Duration column').toContain('Duration');

		testInfo.annotations.push({type: 'notes', description: `${rowCount} rows in datatable`});
	});

	test('V33: Detail panel shows chain metadata for selected row', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		await monitor.selectRow(0);

		const chainName = await monitor.getDetailChainName();
		expect(chainName, 'Detail panel should show chain name').toBeTruthy();

		const status = await monitor.getDetailStatus();
		expect(status, 'Detail panel should show status badge').toBeTruthy();
		expect([
			'Running',
			'Completed',
			'Failed',
			'Aborted',
			'Stalled'
		], 'Status should be a valid value').toContain(status.trim());

		const hasTimeline = await monitor.hasStepTimeline();
		expect(hasTimeline, 'Detail panel should show step timeline').toBeTruthy();

		const hasProgressBar = await monitor.hasProgressBar();
		expect(hasProgressBar, 'Detail panel should show progress bar').toBeTruthy();

		const timingLabels = await monitor.getTimingLabels();
		expect(timingLabels, 'Should show Started in timing').toContain('Started');
		expect(timingLabels, 'Should show Duration in timing').toContain('Duration');
		expect(timingLabels, 'Should show Correlation ID in timing').toContain('Correlation ID');

		testInfo.annotations.push({type: 'notes', description: `${chainName}: ${status}`});
	});

	test('V34: Step timeline renders icons and step names', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		await monitor.selectRow(0);
		await page.waitForTimeout(2000);

		const stepCount = await monitor.getStepCount();
		expect(stepCount, 'Timeline should show steps').toBeGreaterThan(0);

		const stepNames = await monitor.getStepNames();
		expect(stepNames.length, 'Step names should be rendered').toBeGreaterThan(0);

		testInfo.annotations.push({type: 'notes', description: `${stepCount} steps: ${stepNames.join(', ')}`});
	});

	test('V35: Failed chain shows error message in detail', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		// Pin the row to the named fixture: "first row containing Failed" broke whenever a foreign
		// failed chain (with a different error text) was newest, so the search narrows to the one
		// chain whose FailingStep error this test asserts on.
		await monitor.setNameSearch('E2E_MonitorFailChain');
		let rows = await monitor.getRowTexts();
		let failedIndex = rows.findIndex(t => t.includes('Failed'));

		if(failedIndex < 0)
		{
			testInfo.annotations.push({type: 'notes', description: 'No failed fixture chain — launching one'});
			executeAnonymousApex(`
				kern.UTIL_AsyncChain.newChain('E2E_MonitorFailChain')
						.then(new SubscriberChainSteps.FailingStep())
						.execute();
			`);
			await page.waitForTimeout(15000);
			await monitor.navigate();
			await monitor.setNameSearch('E2E_MonitorFailChain');
			await page.waitForTimeout(3000);

			rows = await monitor.getRowTexts();
			failedIndex = rows.findIndex(t => t.includes('Failed'));
			expect(failedIndex, 'Failed fixture chain should appear in list').toBeGreaterThanOrEqual(0);
		}

		await monitor.selectRow(failedIndex);
		await page.waitForTimeout(3000);

		const status = await monitor.getDetailStatus();
		expect(status.trim(), 'Detail should show Failed status').toBe('Failed');

		await monitor.expandErrorAccordion();

		const errorText = await monitor.getErrorText();
		expect(errorText, 'Error section should contain error message').toBeTruthy();
		expect(errorText, 'Error should mention the failure reason').toContain('Deliberate');

		testInfo.annotations.push({type: 'notes', description: `Error: ${errorText.substring(0, 80)}`});
	});

	test('V36: Filter toggle shows and hides status checkboxes', async({page}) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		let filtersVisible = await monitor.hasFiltersVisible();
		expect(filtersVisible, 'Filters should be hidden by default').toBeFalsy();

		await monitor.toggleFilters();
		filtersVisible = await monitor.hasFiltersVisible();
		expect(filtersVisible, 'Filters should be visible after toggle').toBeTruthy();

		await monitor.toggleFilters();
		filtersVisible = await monitor.hasFiltersVisible();
		expect(filtersVisible, 'Filters should be hidden after second toggle').toBeFalsy();
	});

	test('V37: Column sorting changes row order', async({page}, testInfo) =>
	{
		monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		const beforeRows = await monitor.getRowTexts();
		const beforeFirst = beforeRows[0]?.substring(0, 40);

		await monitor.clickColumnHeader('Chain Name');
		await page.waitForTimeout(3000);
		await waitForSpinnerGone(page);

		const afterRows = await monitor.getRowTexts();
		const afterFirst = afterRows[0]?.substring(0, 40);

		expect(afterRows.length, 'Should still have rows after sort').toBeGreaterThan(0);
		expect(afterFirst, 'First row should change after sorting by Chain Name').not.toBe(beforeFirst);

		const headerText = await monitor.getDatatable().locator('thead').innerText();
		expect(headerText, 'Chain Name should show sort indicator').toContain('Chain Name');

		testInfo.annotations.push({type: 'notes', description: `Before: ${beforeFirst}, After: ${afterFirst}`});
	});

	test('V38: Launched chain appears in monitor and shows correct detail', async({page}, testInfo) =>
	{
		const output = executeAnonymousApex(`
			String executionId = kern.UTIL_AsyncChain.newChain('E2E_MonitorLaunch')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.execute();
			System.debug('CHAIN_ID:' + executionId);
		`);

		const match = output.match(/CHAIN_ID:([a-zA-Z0-9]{15,18})/);
		expect(match, 'Should capture chain execution ID').toBeTruthy();
		const chainId = match[1];
		testInfo.annotations.push({type: 'notes', description: `Launched 2-step chain ${chainId}`});

		const records = soqlQuery(`SELECT kern__Status__c, kern__CompletedSteps__c, kern__TotalSteps__c
                                   FROM kern__AsyncChainExecution__c
                                   WHERE Id = '${chainId}'`);
		const execution = records[0];
		testInfo.annotations.push({type: 'notes', description: `DB: ${execution.kern__Status__c}, ${execution.kern__CompletedSteps__c}/${execution.kern__TotalSteps__c}`});

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__AsyncChainExecution__c/${chainId}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);
		await page.waitForTimeout(5000);

		const timeline = page.locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		await expect(timeline).toBeVisible({timeout: 15000});

		const stepRows = timeline.locator('[data-testid="step-row"]');
		const stepCount = await stepRows.count();
		expect(stepCount, 'Step timeline should show all steps').toBe(Number(execution.kern__TotalSteps__c));

		testInfo.annotations.push({type: 'notes', description: `Record page timeline: ${stepCount} steps`});
	});

	test('V39: Chain execution record page has embedded step timeline', async({page}) =>
	{
		const records = soqlQuery('SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = \'E2E_OnboardingChain\' ORDER BY CreatedDate DESC LIMIT 1');
		expect(records.length).toBeGreaterThan(0);

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__AsyncChainExecution__c/${records[0].Id}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);
		await page.waitForTimeout(5000);

		const timeline = page.locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		const isVisible = await timeline.isVisible({timeout: 10000}).catch(() => false);
		expect(isVisible, 'Step timeline should be visible on record page').toBeTruthy();
	});

	test('V115: Operator abort — permission-present happy path on a stalled chain', async({page}, testInfo) =>
	{
		const monitor = new ChainMonitorPage(page);
		executeAnonymousApex(`
			Id abortPermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'AsyncChainAbort' AND NamespacePrefix = 'kern'].Id;
			if([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :abortPermissionSetId] == 0)
			{
				insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = abortPermissionSetId);
			}
		`);

		const output = executeAnonymousApex(`
			kern__AsyncChainExecution__c stalled = new kern__AsyncChainExecution__c(
					kern__ChainName__c = 'E2E_AbortTarget',
					kern__Status__c = 'Stalled',
					kern__TotalSteps__c = 3,
					kern__CompletedSteps__c = 1,
					kern__StartedAt__c = Datetime.now().addMinutes(-10),
					kern__CorrelationId__c = 'e2e-abort-' + String.valueOf(Crypto.getRandomInteger())
			);
			insert stalled;
			System.debug('CHAIN_ID:' + stalled.Id);
		`);
		const chainId = output.match(/CHAIN_ID:([a-zA-Z0-9]{15,18})/)[1];
		testInfo.annotations.push({type: 'notes', description: `Seeded stalled chain ${chainId}`});

		await monitor.navigate();
		await monitor.selectRowByChainName('E2E_AbortTarget');

		const abortButton = monitor.getAbortButton();
		await expect(abortButton).toBeVisible({timeout: 15000});
		await expect(abortButton.locator('button')).toBeEnabled();
		await abortButton.click();

		await monitor.getConfirmButton().click();
		await expect(monitor.getStatusBadge()).toHaveText('Aborted', {timeout: 15000});

		const records = soqlQuery(`SELECT kern__Status__c, kern__FailureCategory__c, kern__CompletedAt__c
		                           FROM kern__AsyncChainExecution__c WHERE Id = '${chainId}'`);
		expect(records[0].kern__Status__c).toBe('Aborted');
		expect(records[0].kern__FailureCategory__c).toBe('OperatorAbort');
		expect(records[0].kern__CompletedAt__c).toBeTruthy();
	});

	test('V116: Operator retry — idempotent failed chain recovers end-to-end', async({page}, testInfo) =>
	{
		test.setTimeout(240_000);
		ensureOperatorSetup();
		const monitor = new ChainMonitorPage(page);

		const chainId = launchChain('E2E_RetryRecovery', '', 'RecoveringStep');
		await waitForChainStatus(page, chainId, 'Failed');
		testInfo.annotations.push({type: 'notes', description: `Recovering chain failed first run: ${chainId}`});

		await monitor.navigate();
		await monitor.selectRowByChainName('E2E_RetryRecovery');

		const retryButton = monitor.getRetryButton();
		await expect(retryButton).toBeVisible({timeout: 15000});
		await expect(retryButton.locator('button')).toBeEnabled();
		await retryButton.click();

		await expect(page.locator('lightning-modal-header')).toContainText('Retry chain from failed step');
		await expect(monitor.getModalBody()).toContainText('E2E_RetryRecovery');
		await expect(monitor.getModalBody()).toContainText('Steps that already completed do not run again.');
		await expect(monitor.getConfirmButton()).toHaveText('Retry chain');
		await monitor.getConfirmButton().click();

		await expect(monitor.getToast()).toContainText(RETRY_SUCCESS_TOAST, {timeout: 15000});
		await expect(monitor.getStatusBadge()).toHaveText('Running', {timeout: 15000});

		await waitForChainStatus(page, chainId, 'Completed');
		await monitor.selectRowByChainName('E2E_RetryRecovery');
		await expect(monitor.getStatusBadge()).toHaveText('Completed', {timeout: 15000});
	});

	test('V117: Operator retry — non-idempotent failed chain shows disabled action with refusal tooltip', async({page}) =>
	{
		test.setTimeout(180_000);
		ensureOperatorSetup();
		const monitor = new ChainMonitorPage(page);

		const chainId = launchChain('E2E_RetryNotIdempotent', '', 'FailingStep');
		await waitForChainStatus(page, chainId, 'Failed');

		await monitor.navigate();
		await monitor.selectRowByChainName('E2E_RetryNotIdempotent');

		const retryButton = monitor.getRetryButton();
		await expect(retryButton).toBeVisible({timeout: 15000});
		await expect(retryButton.locator('button')).toBeDisabled();
		expect(await monitor.getActionTooltip(retryButton), 'Disabled retry should carry the step-not-idempotent refusal').toBe(RETRY_NOT_IDEMPOTENT_TOOLTIP);
		// A browser suppresses pointer events on a disabled control, so the tooltip never fires and
		// nothing reaches a screen reader unless the refusal is also an accessible description.
		await expect(retryButton.locator('button'), 'A screen reader must be told why retry is refused')
		.toHaveAccessibleDescription(RETRY_NOT_IDEMPOTENT_TOOLTIP);
		// And a disabled button takes no focus, so the sighted keyboard-only reader needs it on screen.
		await expect(monitor.getUnavailableNotes().filter({hasText: RETRY_NOT_IDEMPOTENT_TOOLTIP}), 'The refusal must be readable without a pointer')
		.toHaveCount(1);
	});

	test('V122: Detail header — every action stays inside the pane and clear of the chain name at 1600, 1280 and 1024', async({page}) =>
	{
		test.setTimeout(240_000);
		ensureOperatorSetup();
		const monitor = new ChainMonitorPage(page);

		// A failed, restart-declared chain renders the widest header the monitor ever shows:
		// Retry from failed step · Restart from start · divider · View logs.
		const chainId = launchChain('E2E_ToolbarLayout', '.allowRestart()', 'FailingStep');
		await waitForChainStatus(page, chainId, 'Failed');

		await monitor.navigate();
		await monitor.selectRowByChainName('E2E_ToolbarLayout');
		await expect(monitor.getToolbarRow()).toBeVisible({timeout: 15000});
		// The whole U1 defect was buttons living in the identity row, which never wrapped.
		await expect(monitor.getIdentityRow().locator('lightning-button'), 'The identity row must hold no buttons').toHaveCount(0);
		await expect(monitor.getViewLogsButton()).toBeVisible();

		for(const width of HEADER_LAYOUT_WIDTHS)
		{
			await expectHeaderFitsPane(page, monitor, width);
		}
	});

	test('V118: Operator restart — declared chain clones a new run, selects it, and links its lineage', async({page}, testInfo) =>
	{
		test.setTimeout(240_000);
		ensureOperatorSetup();
		const monitor = new ChainMonitorPage(page);

		const chainId = launchChain('E2E_RestartLineage', '.allowRestart()', 'FailingStep');
		await waitForChainStatus(page, chainId, 'Failed');

		await monitor.navigate();
		await monitor.selectRowByChainName('E2E_RestartLineage');

		const restartButton = monitor.getRestartButton();
		await expect(restartButton).toBeVisible({timeout: 15000});
		await expect(restartButton.locator('button')).toBeEnabled();
		await restartButton.click();

		await expect(page.locator('lightning-modal-header')).toContainText('Restart chain from start');
		await expect(monitor.getModalBody()).toContainText('E2E_RestartLineage');
		await expect(monitor.getConfirmButton()).toHaveText('Restart chain');
		await monitor.getConfirmButton().click();

		await expect(monitor.getToast()).toContainText(RESTART_SUCCESS_TOAST, {timeout: 15000});
		// The clone's existence is witnessed by the SOQL read below and its on-screen selection by
		// the lineage link (every DOM row-counting form saturates at the page size or tautologises
		// on the same-named source row — both failure modes were hit and removed).
		await expect(monitor.getLineageLink(), 'The selected clone should link its restart lineage').toBeVisible({timeout: 20000});

		const cloneRows = soqlQuery(`SELECT Id FROM ${prefixed('AsyncChainExecution__c')} WHERE ${prefixed('ChainName__c')} = 'E2E_RestartLineage'`
				+ ` AND ${prefixed('SourceExecution__c')} = '${chainId}'`);
		expect(cloneRows.length, 'Restart should clone exactly one new run linked to its source').toBe(1);
		// The LIST's own selection must reach the clone too — the detail pane alone would render
		// the lineage link from its local state even if the list selection silently stayed put.
		await expect.poll(() => monitor.getSelectedRowKey(), {timeout: 20000}).toBe(cloneRows[0].Id);
		testInfo.annotations.push({type: 'notes', description: `Source ${chainId} cloned to ${cloneRows[0].Id}`});
	});

	test('V119: Operator clear-stalled — sweep reports per-bucket counts in the result toast', async({page}, testInfo) =>
	{
		test.setTimeout(180_000);
		ensureOperatorSetup();
		const monitor = new ChainMonitorPage(page);
		const executionObject = prefixed('AsyncChainExecution__c');

		executeAnonymousApex(`
			List<${executionObject}> strays = [SELECT Id FROM ${executionObject} WHERE ${prefixed('Status__c')} = 'Stalled'];
			for(${executionObject} stray : strays)
			{
				stray.${prefixed('Status__c')} = 'Failed';
			}
			update strays;
		`);
		executeAnonymousApex(`
			List<${executionObject}> seeds = new List<${executionObject}>();
			for(Integer index = 0; index < 2; index++)
			{
				seeds.add(new ${executionObject}(
						${prefixed('ChainName__c')} = 'E2E_ClearStalledSeed',
						${prefixed('Status__c')} = 'Stalled',
						${prefixed('TotalSteps__c')} = 3,
						${prefixed('CompletedSteps__c')} = 1,
						${prefixed('StartedAt__c')} = Datetime.now().addMinutes(-30),
						${prefixed('CorrelationId__c')} = 'e2e-clear-' + index + '-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
				));
			}
			insert seeds;
		`);

		await monitor.navigate();
		await expect(monitor.getOperationsControl()).toBeVisible({timeout: 15000});

		const clearStalledButton = monitor.getClearStalledButton();
		await expect(clearStalledButton).toBeVisible();
		await expect(clearStalledButton.locator('button')).toBeEnabled();
		await clearStalledButton.click();

		await expect(page.locator('lightning-modal-header')).toContainText('Clear stalled chains');
		// The number itself is live org state — the watchdog can sweep a seeded row between the seed
		// and the click — so the check is that a count reached the sentence at all, not which one.
		await expect(monitor.getModalBody()).toContainText(/Stalled chains waiting: \d+\./);
		await expect(monitor.getModalBody(), 'The dialog must not promise a re-drive the engine cannot perform').toContainText('cannot be checked');
		await expect(monitor.getConfirmButton()).toHaveText('Clear stalled chains');
		await monitor.getConfirmButton().click();

		const toast = monitor.getToast();
		await expect(toast).toBeVisible({timeout: 20000});
		const toastText = ((await toast.textContent()) || '').trim();
		expect(toastText, 'Clear-stalled toast should render the frozen counts template').toMatch(CLEAR_STALLED_TOAST_PATTERN);
		const [, redriven, markedFailed, remaining] = toastText.match(CLEAR_STALLED_TOAST_PATTERN).map(Number);
		expect(redriven + markedFailed + remaining, 'Bucket counts should sum to the candidates checked').toBe(2);
		testInfo.annotations.push({type: 'notes', description: `Sweep toast: ${toastText}`});
	});

	test('V120: Operator kill switch — suspend and resume round-trip the state badge', async({page}) =>
	{
		test.setTimeout(180_000);
		ensureOperatorSetup();
		const monitor = new ChainMonitorPage(page);
		resetChainProcessingSwitch();

		try
		{
			await monitor.navigate();
			await expect(monitor.getOperationsBadge()).toHaveText(ENABLED_BADGE, {timeout: 15000});

			await monitor.getSuspendButton().click();
			await expect(page.locator('lightning-modal-header')).toContainText('Suspend chain processing');
			await expect(monitor.getModalBody()).toHaveText('Every running chain stops at its next step and new chains stop at once, org-wide, until you resume.');
			await expect(monitor.getConfirmButton()).toHaveText('Suspend chains');
			await monitor.getConfirmButton().click();

			await expect(monitor.getToast()).toContainText(SUSPENDED_TOAST, {timeout: 15000});
			await expect(monitor.getOperationsBadge()).toHaveText(SUSPENDED_BADGE, {timeout: 15000});

			// U38: the suspension greys out Clear stalled, and the reason has to be readable without
			// hovering (a disabled button suppresses its tooltip) and without focusing it (it takes
			// none). The note on screen is the path that needs neither.
			await expect(monitor.getClearStalledButton().locator('button')).toBeDisabled();
			await expect(monitor.getOperationsUnavailableNotes().filter({hasText: REDRIVE_SUSPENDED_REASON}), 'The refusal must be readable without a pointer')
			.toHaveCount(1);
			await expect(monitor.getClearStalledButton().locator('button')).toHaveAccessibleDescription(REDRIVE_SUSPENDED_REASON);

			await monitor.getResumeButton().click();
			await expect(page.locator('lightning-modal-header')).toContainText('Resume chain processing');
			await expect(monitor.getModalBody()).toHaveText('New chains run again. Chains stopped during the suspension stay stopped; restart the ones that should run.');
			await expect(monitor.getConfirmButton()).toHaveText('Resume chains');
			await monitor.getConfirmButton().click();

			await expect(monitor.getToast()).toContainText(RESUMED_TOAST, {timeout: 15000});
			await expect(monitor.getOperationsBadge()).toHaveText(ENABLED_BADGE, {timeout: 15000});
		}
		finally
		{
			// The switch is org-global state: a failed run must never leave chain processing suspended.
			resetChainProcessingSwitch();
		}
	});

	test('V121: Live activity stream — seeded history renders and a live entry appends', async({page}, testInfo) =>
	{
		test.setTimeout(240_000);
		ensureOperatorSetup();
		const monitor = new ChainMonitorPage(page);

		const chainId = launchChain('E2E_StreamSeed', '', 'FailingStep', {withLogCorrelation: true});
		await waitForChainStatus(page, chainId, 'Failed');

		await monitor.navigate();
		await monitor.selectRowByChainName('E2E_StreamSeed');

		await expect(monitor.getStreamPanel()).toBeVisible({timeout: 15000});
		await expect(monitor.getStreamTitle()).toHaveText(STREAM_TITLE);
		// A Failed chain collapses the stream by default so the error section keeps the operator's
		// attention (the validated prototype's P12 decision); the body renders after expanding.
		await expect(monitor.getStreamCaveat()).not.toBeVisible();
		await monitor.getStreamTitle().click();
		await expect(monitor.getStreamCaveat()).toBeVisible();
		await expect(monitor.getStreamEntries().first(), 'The failure log should seed the stream history').toBeVisible({timeout: 20000});

		const records = soqlQuery(`SELECT ${prefixed('CorrelationId__c')} FROM ${prefixed('AsyncChainExecution__c')} WHERE Id = '${chainId}'`);
		const correlationId = records[0][prefixed('CorrelationId__c')];
		const liveProbeMessage = `E2E stream live probe ${Date.now()}`;
		executeAnonymousApex(`
			${apexNamespacePrefix()}LOG_Builder.setCorrelationId('${correlationId}');
			${apexNamespacePrefix()}LOG_Builder.build().error('${liveProbeMessage}').at('EndToEndChainSteps.streamProbe').forRecord('${chainId}').emit();
		`);

		await expect(monitor.getStreamEntries().filter({hasText: 'E2E stream live probe'}).first(), 'The live emission should append to the stream').toBeVisible({timeout: 30000});
		testInfo.annotations.push({type: 'notes', description: `Live probe: ${liveProbeMessage}`});
	});

	test('V123: List empty states — a no-match search and an empty status filter each say what happened', async({page}) =>
	{
		test.setTimeout(180_000);
		const monitor = new ChainMonitorPage(page);
		await monitor.navigate();
		await expect(monitor.getDatatable()).toBeVisible({timeout: 15000});

		// A no-match search used to leave bare column headers over blank space with a paginator
		// reading "Page 1 of 0", beside a detail pane telling the reader to choose from that list.
		await monitor.setNameSearch(NO_MATCH_SEARCH_TERM);
		await expect(monitor.getListEmptyState()).toBeVisible({timeout: 15000});
		await expect(monitor.getListEmptyState()).toContainText('No chain runs match your search');
		await expect(monitor.getDatatable()).toHaveCount(0);
		await expect(monitor.getListPaginator()).toHaveCount(0);

		await monitor.setNameSearch('');
		await expect(monitor.getDatatable()).toBeVisible({timeout: 15000});
		await expect(monitor.getListPaginator()).toBeVisible();

		// Every status unticked used to read as "no status filter" and return the whole list,
		// pixel-identical to every status ticked.
		await monitor.toggleFilters();
		await monitor.getListPanel().getByRole('button', {name: 'Clear All'}).click();
		await page.waitForTimeout(2000);
		await expect(monitor.getListEmptyState()).toBeVisible({timeout: 15000});
		await expect(monitor.getListEmptyState()).toContainText('No statuses are selected');
		await expect(monitor.getDatatable()).toHaveCount(0);
	});

	test('V124: List columns — the chain name outgrows the pinned columns and an unfinished run shows elapsed time', async({page}, testInfo) =>
	{
		test.setTimeout(180_000);
		const monitor = new ChainMonitorPage(page);
		const executionObject = prefixed('AsyncChainExecution__c');

		// A stalled run records no final duration, which is exactly the row whose Duration cell was
		// blank; it is also the row a stuck-chain triage measures. Its own leftovers go first, so a
		// repeated run measures one row rather than a growing pile of them.
		executeAnonymousApex(`
			delete [SELECT Id FROM ${executionObject} WHERE ${prefixed('ChainName__c')} = '${ELAPSED_FIXTURE_CHAIN}'];
		`);
		executeAnonymousApex(`
			insert new ${executionObject}(
					${prefixed('ChainName__c')} = '${ELAPSED_FIXTURE_CHAIN}',
					${prefixed('Status__c')} = 'Stalled',
					${prefixed('TotalSteps__c')} = 3,
					${prefixed('CompletedSteps__c')} = 1,
					${prefixed('StartedAt__c')} = Datetime.now().addMinutes(-92),
					${prefixed('CorrelationId__c')} = 'e2e-elapsed-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))
			);
		`);

		await monitor.navigate();
		await monitor.setNameSearch(ELAPSED_FIXTURE_CHAIN);
		await expect(monitor.getDatatable()).toBeVisible({timeout: 15000});

		// Five columns split evenly truncated the chain name below the very term that was searched
		// for while '1.9s' held a cell twice the width it needed.
		const widths = await monitor.getColumnWidths();
		const [nameWidth, statusWidth] = widths.slice(-COLUMN_COUNT);
		expect(nameWidth, 'The chain name column should outgrow the pinned status column').toBeGreaterThan(statusWidth);

		// Read the whole row rather than a column index: the header cells carry their sort and menu
		// affordances as text, so matching a column by its header label is not dependable.
		const rowTexts = await monitor.getRowTexts();
		expect(rowTexts[0], 'A stalled run should report the time it has been going, marked as elapsed').toContain('elapsed');
		testInfo.annotations.push({type: 'notes', description: `Column widths: ${widths.join(', ')}; row: ${rowTexts[0].replace(/\n/g, ' | ')}`});
	});

	test('V125: Sorting clears a stale selection so the detail pane follows the list', async({page}) =>
	{
		test.setTimeout(180_000);
		const monitor = new ChainMonitorPage(page);
		await monitor.navigate();
		await expect(monitor.getDatatable()).toBeVisible({timeout: 15000});

		// The last row on the page: a re-sort will not leave it first, so the selection has to move.
		const keysBeforeSort = await monitor.getRowKeys();
		expect(keysBeforeSort.length, 'The org needs more than one chain for this check to mean anything').toBeGreaterThan(1);
		await monitor.selectRow(keysBeforeSort.length - 1);

		// Re-sorting rebuilds the whole result, so the pane used to keep showing a chain that no row
		// highlighted, and could keep showing one the new filter excluded.
		await monitor.clickColumnHeader('Chain Name');

		const keysAfterSort = await monitor.getRowKeys();
		expect(await monitor.getSelectedRowKey(), 'The sort should leave the first row of the new order selected').toBe(keysAfterSort[0]);
		const firstRowName = (await monitor.getChainNameHeading().textContent()).trim();
		expect((await monitor.getRowTexts())[0], 'The detail pane must show the newly selected first row').toContain(firstRowName);
	});
});
