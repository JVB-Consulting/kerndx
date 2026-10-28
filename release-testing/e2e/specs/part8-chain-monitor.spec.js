// SPDX-License-Identifier: BUSL-1.1
const fs = require('fs');
const path = require('path');
const {test, expect} = require('@playwright/test');
const ChainMonitorPage = require('../pages/chain-monitor.page');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {executeAnonymousApex, soqlQuery} = require('../helpers/sf-cli');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {namespacePrefix, apexNamespacePrefix} = require('../helpers/sf-namespace');
const {deployMetadataDir} = require('../../runner/cmdt-deployer');
const {readShippedLabelValues} = require('../lib/shipped-labels');

// --- Operator-action fixtures (V116+): frozen copy of record from the operator-actions mockup ---
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
// renders: Retry from failed step · Restart from start · divider · View logs. The fourth is the
// phone width at which the list and the detail stop sitting side by side and stack instead.
const HEADER_LAYOUT_WIDTHS = [
	1600,
	1280,
	1024,
	500
];
const HEADER_LAYOUT_VIEWPORT_HEIGHT = 900;
const RELAYOUT_SETTLE_MS = 1000;
const MINIMUM_HEADER_ACTIONS = 3;
// V123/V124: a term no seeded chain name can contain, and the stalled fixture whose run has no
// recorded duration — the row whose Duration cell used to be blank.
const NO_MATCH_SEARCH_TERM = 'zzzznomatchzzz';
const ELAPSED_FIXTURE_CHAIN = 'E2E_ElapsedDuration';
const COLUMN_COUNT = 5;
// V145: the recovering chain whose failed step an operator retries; V146: four runs of one chain
// name, two finished, one stalled and one that ended without storing a duration, whose Duration
// order is the point of the journey.
const MANUAL_RETRY_FIXTURE_CHAIN = 'E2E_ManualRetryMarker';
const ELAPSED_SORT_FIXTURE_CHAIN = 'E2E_ElapsedSort';
// The crashed run's Duration cell: one hour and nothing after it, so a wrong value such as 1h 40m cannot pass.
const EXACTLY_ONE_HOUR = /\b1h\b(?! \d)/;
// The retry toast names the chain it retried, so V145 cannot borrow V116's RETRY_SUCCESS_TOAST.
const MANUAL_RETRY_SUCCESS_TOAST = `Retry started. ${MANUAL_RETRY_FIXTURE_CHAIN} resumes at its failed step.`;
// V145: the step words the timeline shows for its two steps (the ChainMonitor_StatusFailed, _StatusDidNotRun and
// _StatusCompleted labels). Before the retry the first step failed and the second never started; after it, both ran.
const STEP_WORDS_BEFORE_RETRY = ['Failed', 'Did not run'];
const STEP_WORDS_AFTER_RETRY = ['Completed', 'Completed'];

let operatorSetupDone = false;
let operatorFixtureDone = false;

// Object and field API names carry the package prefix only on the subscriber org.
function prefixed(apiName)
{
	return `${namespacePrefix()}${apiName}`;
}

// A permission set query's namespace filter: the package's namespace on a subscriber org, none on the development org.
function namespaceClause()
{
	const prefix = namespacePrefix();
	return prefix ? `NamespacePrefix = '${prefix.slice(0, -2)}'` : 'NamespacePrefix = NULL';
}

// The dev-org fixture compiles unprefixed; the subscriber org uses the managed-referencing fixture.
function operatorStepsClass()
{
	return namespacePrefix() ? 'SubscriberChainSteps' : 'EndToEndChainSteps';
}

// The development fixture as it stands in this checkout. Every step class it declares must be in the
// org's copy; an org that lacks one holds an older fixture. Read from the file, so adding a step to the
// fixture needs no second edit here, and a stale org is found without a deploy on every run.
const CHAIN_STEPS_FIXTURE_CLASS = path.join(CHAIN_STEPS_FIXTURE_DIR, 'metadata', 'classes', 'EndToEndChainSteps.cls');
const STEP_CLASS_DECLARATION = /public class (\w+) extends/g;

function fixtureStepNames()
{
	const source = fs.readFileSync(CHAIN_STEPS_FIXTURE_CLASS, 'utf8');
	return [...source.matchAll(STEP_CLASS_DECLARATION)].map(match => match[1]);
}

// Puts the development fixture class on the org when it is absent or older than the steps these
// journeys name. The subscriber org gets SubscriberChainSteps from the runbook, so this does
// nothing there. Separate from the permission-set half below, which only the operator actions need.
function ensureOperatorFixture()
{
	if(operatorFixtureDone || namespacePrefix())
	{
		return;
	}
	const fixtureRows = soqlQuery(`SELECT Body FROM ApexClass WHERE Name = '${operatorStepsClass()}' LIMIT 1`, {tooling: true});
	const fixtureBody = fixtureRows.length > 0 ? fixtureRows[0].Body : '';
	const orgHoldsEveryStep = fixtureStepNames().every(stepName => fixtureBody.includes(`class ${stepName} extends`));
	if(!orgHoldsEveryStep)
	{
		deployMetadataDir(CHAIN_STEPS_FIXTURE_DIR);
	}
	operatorFixtureDone = true;
}

function ensureOperatorSetup()
{
	if(operatorSetupDone)
	{
		return;
	}
	ensureOperatorFixture();
	executeAnonymousApex(`
		List<PermissionSet> operatorSets = [SELECT Id FROM PermissionSet WHERE Name IN ('AsyncChainRedrive', 'AsyncChainKillSwitch') AND ${namespaceClause()}];
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
	// chain UUID its logs never carry — raised as an engine gap (ChainBuilder line 2185
	// still serializes the no-argument context).
	const correlationStatement = options.withLogCorrelation ? `${apexNamespacePrefix()}LOG_Builder.startCorrelation();` : '';
	// A step the chain runs after the first one, when the journey needs a step that waits on it.
	const followingStep = options.followingStepClassName ? `.then(new ${operatorStepsClass()}.${options.followingStepClassName}())` : '';
	const output = executeAnonymousApex(`
		${correlationStatement}
		String executionId = ${apexNamespacePrefix()}UTIL_AsyncChain.newChain('${chainName}')${builderCalls}
				.then(new ${operatorStepsClass()}.${stepClassName}())${followingStep}
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
	for(; ;)
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

// V39 opens a chain execution record page. An earlier part of the runbook seeds the onboarding run
// on the subscriber leg, so that name is the only one tried there; on the development org no
// earlier part has run, and V38 a few journeys above leaves a finished run of the launch chain.
const RUNBOOK_SEEDED_CHAIN = 'E2E_OnboardingChain';
const RECORD_PAGE_LAUNCHED_CHAIN = 'E2E_MonitorLaunch';
const RECORD_PAGE_CHAIN_NAMES = [
	RUNBOOK_SEEDED_CHAIN,
	RECORD_PAGE_LAUNCHED_CHAIN
];

// The newest run of the first of these chain names that has one, or null when none of them has run.
// Each query is the one V39 has always issued, so a subscriber org lands on its seeded run as before.
function findNewestExecutionId(executionObject, chainNames)
{
	for(const chainName of chainNames)
	{
		const chainQuery = `SELECT Id FROM ${executionObject} WHERE ${prefixed('ChainName__c')} = '${chainName}' ORDER BY CreatedDate DESC LIMIT 1`;
		const records = soqlQuery(chainQuery);
		if(records.length > 0)
		{
			return records[0].Id;
		}
	}
	return null;
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
	return first.x < second.x + second.width && first.x + first.width > second.x && first.y < second.y + second.height && first.y + first.height > second.y;
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

		// The panel can carry a second copy button, so this one has to say what it copies.
		const copyCorrelationLabel = readShippedLabelValues().ChainMonitor_CopyCorrelation;
		expect(copyCorrelationLabel, 'The package ships a name for the correlation id copy button').toBeDefined();
		const copyName = await monitor.getCopyCorrelationName();
		expect(copyName.title, 'The correlation id copy tooltip says what that button copies').toBe(copyCorrelationLabel);
		expect(copyName.spoken, 'The correlation id copy button is read out by what it copies').toBe(copyCorrelationLabel);

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
			ensureOperatorFixture();
			executeAnonymousApex(`
				${apexNamespacePrefix()}UTIL_AsyncChain.newChain('E2E_MonitorFailChain')
						.then(new ${operatorStepsClass()}.FailingStep())
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

		// The panel names itself and its two actions say what they do; a no-op action is disabled.
		await expect(monitor.statusLegend(), 'The status group shows a visible Status legend').toBeVisible();
		await expect(monitor.statusAction('Clear all'), 'Clear all is live while statuses are selected').toBeEnabled();
		await expect(monitor.statusAction('Select all'), 'Select all is disabled while every status is selected').toBeDisabled();
		await monitor.statusAction('Clear all').click();
		await page.waitForTimeout(500);
		await expect(monitor.statusAction('Clear all'), 'Clear all is disabled once nothing is selected').toBeDisabled();
		await expect(monitor.statusAction('Select all'), 'Select all is live once nothing is selected').toBeEnabled();
		await expect(monitor.listEmptyState(), 'Zero statuses shows the explicit empty state').toBeVisible();
		await monitor.statusAction('Select all').click();
		await page.waitForTimeout(500);

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
		ensureOperatorFixture();
		const output = executeAnonymousApex(`
			String executionId = ${apexNamespacePrefix()}UTIL_AsyncChain.newChain('${RECORD_PAGE_LAUNCHED_CHAIN}')
					.then(new ${operatorStepsClass()}.CreateFoobarStep())
					.then(new ${operatorStepsClass()}.UpdateFoobarStep())
					.execute();
			System.debug('CHAIN_ID:' + executionId);
		`);

		const match = output.match(/CHAIN_ID:([a-zA-Z0-9]{15,18})/);
		expect(match, 'Should capture chain execution ID').toBeTruthy();
		const chainId = match[1];
		testInfo.annotations.push({type: 'notes', description: `Launched 2-step chain ${chainId}`});

		const executionObject = prefixed('AsyncChainExecution__c');
		const records = soqlQuery(`SELECT ${prefixed('Status__c')}, ${prefixed('CompletedSteps__c')}, ${prefixed('TotalSteps__c')}
                                   FROM ${executionObject}
                                   WHERE Id = '${chainId}'`);
		const execution = records[0];
		const executionStatus = execution[prefixed('Status__c')];
		const completedSteps = execution[prefixed('CompletedSteps__c')];
		const totalSteps = execution[prefixed('TotalSteps__c')];
		testInfo.annotations.push({type: 'notes', description: `DB: ${executionStatus}, ${completedSteps}/${totalSteps}`});

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/${executionObject}/${chainId}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);
		await page.waitForTimeout(5000);

		const timeline = page.locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		await expect(timeline).toBeVisible({timeout: 15000});

		const stepRows = timeline.locator('[data-testid="step-row"]');
		const stepCount = await stepRows.count();
		expect(stepCount, 'Step timeline should show all steps').toBe(Number(totalSteps));

		testInfo.annotations.push({type: 'notes', description: `Record page timeline: ${stepCount} steps`});
	});

	test('V39: Chain execution record page has embedded step timeline', async({page}) =>
	{
		const executionObject = prefixed('AsyncChainExecution__c');
		// On an org with the package installed the runbook seeds the onboarding run before this part, and its
		// absence is a finding, so only that name is tried there and nothing is launched in its place.
		const packageInstalled = Boolean(namespacePrefix());
		let executionId = findNewestExecutionId(executionObject, packageInstalled ? [RUNBOOK_SEEDED_CHAIN] : RECORD_PAGE_CHAIN_NAMES);
		if(!executionId && !packageInstalled)
		{
			ensureOperatorFixture();
			executionId = launchChain(RECORD_PAGE_LAUNCHED_CHAIN, '', 'CreateFoobarStep');
			await waitForChainStatus(page, executionId, 'Completed');
		}
		const missingRunMessage = packageInstalled ? `A run of ${RUNBOOK_SEEDED_CHAIN} should exist: an earlier part of the runbook seeds it` : 'A chain run should be available';
		expect(executionId, missingRunMessage).toBeTruthy();

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/${executionObject}/${executionId}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);
		await page.waitForTimeout(5000);

		const timeline = page.locator('c-chain-step-timeline, kern-chain-step-timeline').first();
		const isVisible = await timeline.isVisible({timeout: 10000}).catch(() => false);
		expect(isVisible, 'Step timeline should be visible on record page').toBeTruthy();
	});

	test('V115: Operator abort — permission-present happy path on a stalled chain', async({page}, testInfo) =>
	{
		const chainMonitor = new ChainMonitorPage(page);
		executeAnonymousApex(`
			Id abortPermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'AsyncChainAbort' AND ${namespaceClause()}].Id;
			if([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :abortPermissionSetId] == 0)
			{
				insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = abortPermissionSetId);
			}
		`);

		const executionObject = prefixed('AsyncChainExecution__c');
		const output = executeAnonymousApex(`
			${executionObject} stalled = new ${executionObject}(
					${prefixed('ChainName__c')} = 'E2E_AbortTarget',
					${prefixed('Status__c')} = 'Stalled',
					${prefixed('TotalSteps__c')} = 3,
					${prefixed('CompletedSteps__c')} = 1,
					${prefixed('StartedAt__c')} = Datetime.now().addMinutes(-10),
					${prefixed('CorrelationId__c')} = 'e2e-abort-' + String.valueOf(Crypto.getRandomInteger())
			);
			insert stalled;
			System.debug('CHAIN_ID:' + stalled.Id);
		`);
		const chainId = output.match(/CHAIN_ID:([a-zA-Z0-9]{15,18})/)[1];
		testInfo.annotations.push({type: 'notes', description: `Seeded stalled chain ${chainId}`});

		await chainMonitor.navigate();
		await chainMonitor.selectRowByChainName('E2E_AbortTarget');

		const abortButton = chainMonitor.getAbortButton();
		await expect(abortButton).toBeVisible({timeout: 15000});
		await expect(abortButton.locator('button')).toBeEnabled();
		await abortButton.click();

		await chainMonitor.getConfirmButton().click();
		await expect(chainMonitor.getStatusBadge()).toHaveText('Aborted', {timeout: 15000});

		const records = soqlQuery(`SELECT ${prefixed('Status__c')}, ${prefixed('FailureCategory__c')}, ${prefixed('CompletedAt__c')}
		                           FROM ${executionObject} WHERE Id = '${chainId}'`);
		expect(records[0][prefixed('Status__c')]).toBe('Aborted');
		expect(records[0][prefixed('FailureCategory__c')]).toBe('OperatorAbort');
		expect(records[0][prefixed('CompletedAt__c')]).toBeTruthy();
	});

	test('V116: Operator retry — idempotent failed chain recovers end-to-end', async({page}, testInfo) =>
	{
		test.setTimeout(240_000);
		ensureOperatorSetup();
		const chainMonitor = new ChainMonitorPage(page);

		const chainId = launchChain('E2E_RetryRecovery', '', 'RecoveringStep');
		await waitForChainStatus(page, chainId, 'Failed');
		testInfo.annotations.push({type: 'notes', description: `Recovering chain failed first run: ${chainId}`});

		await chainMonitor.navigate();
		await chainMonitor.selectRowByChainName('E2E_RetryRecovery');

		const retryButton = chainMonitor.getRetryButton();
		await expect(retryButton).toBeVisible({timeout: 15000});
		await expect(retryButton.locator('button')).toBeEnabled();
		await retryButton.click();

		await expect(page.locator('lightning-modal-header')).toContainText('Retry chain from failed step');
		await expect(chainMonitor.getModalBody()).toContainText('E2E_RetryRecovery');
		await expect(chainMonitor.getModalBody()).toContainText('Steps that already completed do not run again.');
		await expect(chainMonitor.getConfirmButton()).toHaveText('Retry chain');
		await chainMonitor.getConfirmButton().click();

		await expect(chainMonitor.getToast()).toContainText(RETRY_SUCCESS_TOAST, {timeout: 15000});
		await expect(chainMonitor.getStatusBadge()).toHaveText('Running', {timeout: 15000});

		await waitForChainStatus(page, chainId, 'Completed');
		await chainMonitor.selectRowByChainName('E2E_RetryRecovery');
		await expect(chainMonitor.getStatusBadge()).toHaveText('Completed', {timeout: 15000});
	});

	test('V117: Operator retry — non-idempotent failed chain shows disabled action with refusal tooltip', async({page}) =>
	{
		test.setTimeout(180_000);
		ensureOperatorSetup();
		const chainMonitor = new ChainMonitorPage(page);

		const chainId = launchChain('E2E_RetryNotIdempotent', '', 'FailingStep');
		await waitForChainStatus(page, chainId, 'Failed');

		await chainMonitor.navigate();
		await chainMonitor.selectRowByChainName('E2E_RetryNotIdempotent');

		const retryButton = chainMonitor.getRetryButton();
		await expect(retryButton).toBeVisible({timeout: 15000});
		await expect(retryButton.locator('button')).toBeDisabled();
		expect(await chainMonitor.getActionTooltip(retryButton), 'Disabled retry should carry the step-not-idempotent refusal').toBe(RETRY_NOT_IDEMPOTENT_TOOLTIP);
		// A browser suppresses pointer events on a disabled control, so the tooltip never fires and
		// nothing reaches a screen reader unless the refusal is also an accessible description.
		await expect(retryButton.locator('button'), 'A screen reader must be told why retry is refused')
		.toHaveAccessibleDescription(RETRY_NOT_IDEMPOTENT_TOOLTIP);
		// And a disabled button takes no focus, so the sighted keyboard-only reader needs it on screen.
		await expect(chainMonitor.getUnavailableNotes().filter({hasText: RETRY_NOT_IDEMPOTENT_TOOLTIP}), 'The refusal must be readable without a pointer')
		.toHaveCount(1);
	});

	test('V122: Detail header — every action stays inside the pane and clear of the chain name at 1600, 1280, 1024 and 500', async({page}) =>
	{
		test.setTimeout(240_000);
		ensureOperatorSetup();
		const chainMonitor = new ChainMonitorPage(page);

		// A failed, restart-declared chain renders the widest header the monitor ever shows:
		// Retry from failed step · Restart from start · divider · View logs.
		const chainId = launchChain('E2E_ToolbarLayout', '.allowRestart()', 'FailingStep');
		await waitForChainStatus(page, chainId, 'Failed');

		await chainMonitor.navigate();
		await chainMonitor.selectRowByChainName('E2E_ToolbarLayout');
		await expect(chainMonitor.getToolbarRow()).toBeVisible({timeout: 15000});
		// The whole U1 defect was buttons living in the identity row, which never wrapped.
		await expect(chainMonitor.getIdentityRow().locator('lightning-button'), 'The identity row must hold no buttons').toHaveCount(0);
		await expect(chainMonitor.getViewLogsButton()).toBeVisible();

		for(const width of HEADER_LAYOUT_WIDTHS)
		{
			await expectHeaderFitsPane(page, chainMonitor, width);
		}
	});

	test('V118: Operator restart — declared chain clones a new run, selects it, and links its lineage', async({page}, testInfo) =>
	{
		test.setTimeout(240_000);
		ensureOperatorSetup();
		const chainMonitor = new ChainMonitorPage(page);

		const chainId = launchChain('E2E_RestartLineage', '.allowRestart()', 'FailingStep');
		await waitForChainStatus(page, chainId, 'Failed');

		await chainMonitor.navigate();
		await chainMonitor.selectRowByChainName('E2E_RestartLineage');

		const restartButton = chainMonitor.getRestartButton();
		await expect(restartButton).toBeVisible({timeout: 15000});
		await expect(restartButton.locator('button')).toBeEnabled();
		await restartButton.click();

		await expect(page.locator('lightning-modal-header')).toContainText('Restart chain from start');
		await expect(chainMonitor.getModalBody()).toContainText('E2E_RestartLineage');
		await expect(chainMonitor.getConfirmButton()).toHaveText('Restart chain');
		await chainMonitor.getConfirmButton().click();

		await expect(chainMonitor.getToast()).toContainText(RESTART_SUCCESS_TOAST, {timeout: 15000});
		// The clone's existence is witnessed by the SOQL read below and its on-screen selection by
		// the Launched under link, which carries the restart lineage on a clone (every DOM
		// row-counting form saturates at the page size or tautologises on the same-named source
		// row, and both failure modes were hit and removed).
		await expect(chainMonitor.getLaunchedUnderLink(), 'The selected clone should link its restart lineage').toBeVisible({timeout: 20000});
		expect(await chainMonitor.getLaunchedUnderLink().innerText(), 'The link names the source').toMatch(/^restart of E2E_RestartLineage · CHAIN-\d+$/);

		const cloneFilter = `${prefixed('ChainName__c')} = 'E2E_RestartLineage' AND ${prefixed('SourceExecution__c')} = '${chainId}'`;
		const cloneRows = soqlQuery(`SELECT Id FROM ${prefixed('AsyncChainExecution__c')} WHERE ${cloneFilter}`);
		expect(cloneRows.length, 'Restart should clone exactly one new run linked to its source').toBe(1);
		// The LIST's own selection must reach the clone too — the detail pane alone would render
		// the lineage link from its local state even if the list selection silently stayed put.
		await expect.poll(() => chainMonitor.getSelectedRowKey(), {timeout: 20000}).toBe(cloneRows[0].Id);
		testInfo.annotations.push({type: 'notes', description: `Source ${chainId} cloned to ${cloneRows[0].Id}`});
	});

	test('V119: Operator clear-stalled — sweep reports per-bucket counts in the result toast', async({page}, testInfo) =>
	{
		test.setTimeout(180_000);
		ensureOperatorSetup();
		const chainMonitor = new ChainMonitorPage(page);
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

		await chainMonitor.navigate();
		await expect(chainMonitor.getOperationsControl()).toBeVisible({timeout: 15000});

		const clearStalledButton = chainMonitor.getClearStalledButton();
		await expect(clearStalledButton).toBeVisible();
		await expect(clearStalledButton.locator('button')).toBeEnabled();
		await clearStalledButton.click();

		await expect(page.locator('lightning-modal-header')).toContainText('Clear stalled chains');
		// The number itself is live org state — the watchdog can sweep a seeded row between the seed
		// and the click — so the check is that a count reached the sentence at all, not which one.
		await expect(chainMonitor.getModalBody()).toContainText(/Stalled chains waiting: \d+\./);
		await expect(chainMonitor.getModalBody(), 'The dialog must not promise a re-drive the engine cannot perform').toContainText('cannot be checked');
		await expect(chainMonitor.getConfirmButton()).toHaveText('Clear stalled chains');
		await chainMonitor.getConfirmButton().click();

		const toast = chainMonitor.getToast();
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
		const chainMonitor = new ChainMonitorPage(page);
		resetChainProcessingSwitch();

		try
		{
			await chainMonitor.navigate();
			await expect(chainMonitor.getOperationsBadge()).toHaveText(ENABLED_BADGE, {timeout: 15000});

			await chainMonitor.getSuspendButton().click();
			await expect(page.locator('lightning-modal-header')).toContainText('Suspend chain processing');
			await expect(chainMonitor.getModalBody()).toHaveText('Every running chain stops at its next step and new chains stop at once, org-wide, until you resume.');
			await expect(chainMonitor.getConfirmButton()).toHaveText('Suspend chains');
			await chainMonitor.getConfirmButton().click();

			await expect(chainMonitor.getToast()).toContainText(SUSPENDED_TOAST, {timeout: 15000});
			await expect(chainMonitor.getOperationsBadge()).toHaveText(SUSPENDED_BADGE, {timeout: 15000});

			// U38: the suspension greys out Clear stalled, and the reason has to be readable without
			// hovering (a disabled button suppresses its tooltip) and without focusing it (it takes
			// none). The note on screen is the path that needs neither.
			await expect(chainMonitor.getClearStalledButton().locator('button')).toBeDisabled();
			await expect(chainMonitor.getOperationsUnavailableNotes().filter({hasText: REDRIVE_SUSPENDED_REASON}), 'The refusal must be readable without a pointer')
			.toHaveCount(1);
			await expect(chainMonitor.getClearStalledButton().locator('button')).toHaveAccessibleDescription(REDRIVE_SUSPENDED_REASON);

			await chainMonitor.getResumeButton().click();
			await expect(page.locator('lightning-modal-header')).toContainText('Resume chain processing');
			await expect(chainMonitor.getModalBody()).toHaveText('New chains run again. Chains stopped during the suspension stay stopped; restart the ones that should run.');
			await expect(chainMonitor.getConfirmButton()).toHaveText('Resume chains');
			await chainMonitor.getConfirmButton().click();

			await expect(chainMonitor.getToast()).toContainText(RESUMED_TOAST, {timeout: 15000});
			await expect(chainMonitor.getOperationsBadge()).toHaveText(ENABLED_BADGE, {timeout: 15000});
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
		const chainMonitor = new ChainMonitorPage(page);

		const chainId = launchChain('E2E_StreamSeed', '', 'FailingStep', {withLogCorrelation: true});
		await waitForChainStatus(page, chainId, 'Failed');

		await chainMonitor.navigate();
		await chainMonitor.selectRowByChainName('E2E_StreamSeed');

		await expect(chainMonitor.getStreamPanel()).toBeVisible({timeout: 15000});
		await expect(chainMonitor.getStreamTitle()).toHaveText(STREAM_TITLE);
		// A Failed chain collapses the stream by default so the error section keeps the operator's
		// attention (the validated prototype's P12 decision); the body renders after expanding.
		await expect(chainMonitor.getStreamCaveat()).not.toBeVisible();
		await chainMonitor.getStreamTitle().click();
		await expect(chainMonitor.getStreamCaveat()).toBeVisible();
		await expect(chainMonitor.getStreamEntries().first(), 'The failure log should seed the stream history').toBeVisible({timeout: 20000});

		const records = soqlQuery(`SELECT ${prefixed('CorrelationId__c')} FROM ${prefixed('AsyncChainExecution__c')} WHERE Id = '${chainId}'`);
		const correlationId = records[0][prefixed('CorrelationId__c')];
		const liveProbeMessage = `E2E stream live probe ${Date.now()}`;
		executeAnonymousApex(`
			${apexNamespacePrefix()}LOG_Builder.setCorrelationId('${correlationId}');
			${apexNamespacePrefix()}LOG_Builder.build().error('${liveProbeMessage}').at('EndToEndChainSteps.streamProbe').forRecord('${chainId}').emit();
		`);

		await expect(chainMonitor.getStreamEntries().filter({hasText: 'E2E stream live probe'}).first(), 'The live emission should append to the stream')
		.toBeVisible({timeout: 30000});
		testInfo.annotations.push({type: 'notes', description: `Live probe: ${liveProbeMessage}`});
	});

	test('V123: List empty states — a no-match search and an empty status filter each say what happened', async({page}) =>
	{
		test.setTimeout(180_000);
		const chainMonitor = new ChainMonitorPage(page);
		await chainMonitor.navigate();
		await expect(chainMonitor.getDatatable()).toBeVisible({timeout: 15000});

		// A no-match search used to leave bare column headers over blank space with a paginator
		// reading "Page 1 of 0", beside a detail pane telling the reader to choose from that list.
		await chainMonitor.setNameSearch(NO_MATCH_SEARCH_TERM);
		await expect(chainMonitor.getListEmptyState()).toBeVisible({timeout: 15000});
		await expect(chainMonitor.getListEmptyState()).toContainText('No chain runs match your search');
		await expect(chainMonitor.getDatatable()).toHaveCount(0);
		await expect(chainMonitor.getListPaginator()).toHaveCount(0);

		await chainMonitor.setNameSearch('');
		await expect(chainMonitor.getDatatable()).toBeVisible({timeout: 15000});
		await expect(chainMonitor.getListPaginator()).toBeVisible();

		// Every status unticked used to read as "no status filter" and return the whole list,
		// pixel-identical to every status ticked.
		await chainMonitor.toggleFilters();
		await chainMonitor.getListPanel().getByRole('button', {name: 'Clear All'}).click();
		await page.waitForTimeout(2000);
		await expect(chainMonitor.getListEmptyState()).toBeVisible({timeout: 15000});
		await expect(chainMonitor.getListEmptyState()).toContainText('No statuses are selected');
		await expect(chainMonitor.getDatatable()).toHaveCount(0);
	});

	test('V124: List columns — the chain name outgrows the pinned columns and an unfinished run shows elapsed time', async({page}, testInfo) =>
	{
		test.setTimeout(180_000);
		const chainMonitor = new ChainMonitorPage(page);
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

		await chainMonitor.navigate();
		await chainMonitor.setNameSearch(ELAPSED_FIXTURE_CHAIN);
		await expect(chainMonitor.getDatatable()).toBeVisible({timeout: 15000});

		// Five columns split evenly truncated the chain name below the very term that was searched
		// for while '1.9s' held a cell twice the width it needed.
		const widths = await chainMonitor.getColumnWidths();
		const [nameWidth, statusWidth] = widths.slice(-COLUMN_COUNT);
		expect(nameWidth, 'The chain name column should outgrow the pinned status column').toBeGreaterThan(statusWidth);

		// Read the whole row rather than a column index: the header cells carry their sort and menu
		// affordances as text, so matching a column by its header label is not dependable.
		const rowTexts = await chainMonitor.getRowTexts();
		expect(rowTexts[0], 'A stalled run should report the time it has been going, marked as elapsed').toContain('elapsed');
		testInfo.annotations.push({type: 'notes', description: `Column widths: ${widths.join(', ')}; row: ${rowTexts[0].replace(/\n/g, ' | ')}`});
	});

	test('V125: Sorting clears a stale selection so the detail pane follows the list', async({page}) =>
	{
		test.setTimeout(180_000);
		const chainMonitor = new ChainMonitorPage(page);
		await chainMonitor.navigate();
		await expect(chainMonitor.getDatatable()).toBeVisible({timeout: 15000});

		// The last row on the page: a re-sort will not leave it first, so the selection has to move.
		const keysBeforeSort = await chainMonitor.getRowKeys();
		expect(keysBeforeSort.length, 'The org needs more than one chain for this check to mean anything').toBeGreaterThan(1);
		await chainMonitor.selectRow(keysBeforeSort.length - 1);

		// Re-sorting rebuilds the whole result, so the pane used to keep showing a chain that no row
		// highlighted, and could keep showing one the new filter excluded.
		await chainMonitor.clickColumnHeader('Chain Name');

		const keysAfterSort = await chainMonitor.getRowKeys();
		expect(await chainMonitor.getSelectedRowKey(), 'The sort should leave the first row of the new order selected').toBe(keysAfterSort[0]);
		const firstRowName = (await chainMonitor.getChainNameHeading().textContent()).trim();
		expect((await chainMonitor.getRowTexts())[0], 'The detail pane must show the newly selected first row').toContain(firstRowName);
	});

	test('V145: Operator retry — the retried step carries its marker and the record says when', async({page}, testInfo) =>
	{
		test.setTimeout(240_000);
		ensureOperatorSetup();
		const chainMonitor = new ChainMonitorPage(page);

		const chainId = launchChain(MANUAL_RETRY_FIXTURE_CHAIN, '', 'RecoveringStep', {followingStepClassName: 'CreateFoobarStep'});
		await waitForChainStatus(page, chainId, 'Failed');

		await chainMonitor.navigate();
		await chainMonitor.selectRowByChainName(MANUAL_RETRY_FIXTURE_CHAIN);
		await expect(chainMonitor.getStatusBadge()).toHaveText('Failed', {timeout: 15000});
		await expect(chainMonitor.getManualRetryMarkers(), 'A run nobody retried shows no marker').toHaveCount(0);
		// The first step failed and the chain ended, so the step after it never started.
		await expect.poll(() => chainMonitor.getStepStateWords(), {message: 'Expected the failed step, then a step that did not run', timeout: 15000})
		.toEqual(STEP_WORDS_BEFORE_RETRY);

		await chainMonitor.getRetryButton().click();
		await chainMonitor.getConfirmButton().click();
		await expect(chainMonitor.getToast()).toContainText(MANUAL_RETRY_SUCCESS_TOAST, {timeout: 15000});

		await waitForChainStatus(page, chainId, 'Completed');
		await chainMonitor.navigate();
		await chainMonitor.selectRowByChainName(MANUAL_RETRY_FIXTURE_CHAIN);
		await expect(chainMonitor.getStatusBadge()).toHaveText('Completed', {timeout: 15000});

		// The marker stays after the retried step succeeds: "this step was retried manually" remains true.
		await expect(chainMonitor.getManualRetryMarkers()).toHaveCount(1);
		await expect(chainMonitor.getManualRetryMarkers().first()).toContainText('Retried manually after');
		// The retry ran the failed step again and then the step after it, so both now say they completed.
		await expect.poll(() => chainMonitor.getStepStateWords(), {message: 'Expected both steps to say they completed', timeout: 15000})
		.toEqual(STEP_WORDS_AFTER_RETRY);

		const records = soqlQuery(`SELECT ${prefixed('LastManualRetryAt__c')} FROM ${prefixed('AsyncChainExecution__c')} WHERE Id = '${chainId}'`);
		expect(records[0][prefixed('LastManualRetryAt__c')], 'The run record says when Retry was last used').toBeTruthy();
		testInfo.annotations.push({type: 'notes', description: `Retried run ${chainId}: ${await chainMonitor.getManualRetryMarkers().first().innerText()}`});
	});

	test('V146: Duration sort — a stalled run sorts by how long it has been going, between finished runs', async({page}, testInfo) =>
	{
		test.setTimeout(180_000);
		const chainMonitor = new ChainMonitorPage(page);
		const executionObject = prefixed('AsyncChainExecution__c');

		executeAnonymousApex(`
			delete [SELECT Id FROM ${executionObject} WHERE ${prefixed('ChainName__c')} = '${ELAPSED_SORT_FIXTURE_CHAIN}'];
		`);
		// The crashed run's end is counted from its start, never from a second reading of the clock, so the
		// two differ by exactly one hour and the row reads "1h". A run cannot be created in a finished status since
		// 1.8, so the seed bypasses the run-transition action for its one insert, by the name the action record
		// carries on a subscriber org (the helper rewrites it for an unmanaged org).
		executeAnonymousApex(`
			kern.TRG_Base.bypassAction('kern.TRG_AsyncChainRunTransition');
			Datetime crashedStart = Datetime.now().addHours(-6);
			List<${executionObject}> runs = new List<${executionObject}>();
			runs.add(new ${executionObject}(${prefixed('ChainName__c')} = '${ELAPSED_SORT_FIXTURE_CHAIN}', ${prefixed('Status__c')} = 'Failed',
					${prefixed('TotalSteps__c')} = 3, ${prefixed('CompletedSteps__c')} = 1, ${prefixed('StartedAt__c')} = crashedStart,
					${prefixed('CompletedAt__c')} = crashedStart.addHours(1),
					${prefixed('CorrelationId__c')} = 'e2e-sort-crashed-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))));
			runs.add(new ${executionObject}(${prefixed('ChainName__c')} = '${ELAPSED_SORT_FIXTURE_CHAIN}', ${prefixed('Status__c')} = 'Completed',
					${prefixed('TotalSteps__c')} = 1, ${prefixed('CompletedSteps__c')} = 1, ${prefixed('StartedAt__c')} = Datetime.now().addHours(-6),
					${prefixed('CompletedAt__c')} = Datetime.now().addHours(-6).addMinutes(10), ${prefixed('DurationMs__c')} = 600000,
					${prefixed('CorrelationId__c')} = 'e2e-sort-short-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))));
			runs.add(new ${executionObject}(${prefixed('ChainName__c')} = '${ELAPSED_SORT_FIXTURE_CHAIN}', ${prefixed('Status__c')} = 'Completed',
					${prefixed('TotalSteps__c')} = 1, ${prefixed('CompletedSteps__c')} = 1, ${prefixed('StartedAt__c')} = Datetime.now().addHours(-6),
					${prefixed('CompletedAt__c')} = Datetime.now().addHours(-3), ${prefixed('DurationMs__c')} = 10800000,
					${prefixed('CorrelationId__c')} = 'e2e-sort-long-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))));
			runs.add(new ${executionObject}(${prefixed('ChainName__c')} = '${ELAPSED_SORT_FIXTURE_CHAIN}', ${prefixed('Status__c')} = 'Stalled',
					${prefixed('TotalSteps__c')} = 3, ${prefixed('CompletedSteps__c')} = 1, ${prefixed('StartedAt__c')} = Datetime.now().addMinutes(-92),
					${prefixed('CorrelationId__c')} = 'e2e-sort-stalled-' + String.valueOf(Math.abs(Crypto.getRandomInteger()))));
			insert runs;
			kern.TRG_Base.clearActionBypass('kern.TRG_AsyncChainRunTransition');
		`);

		await chainMonitor.navigate();
		await chainMonitor.setNameSearch(ELAPSED_SORT_FIXTURE_CHAIN);
		await expect(chainMonitor.getDatatable()).toBeVisible({timeout: 15000});
		await chainMonitor.clickColumnHeader('Duration');
		await page.waitForTimeout(3000);
		await waitForSpinnerGone(page);

		const rowTexts = await chainMonitor.getRowTexts();
		expect(rowTexts.length, 'The four seeded runs are listed').toBe(4);
		// Ten minutes, one hour, ninety-two minutes and three hours: the two middle rows are the crashed run and
		// the stalled one, in the order the column points.
		const middleRows = [
			rowTexts[1],
			rowTexts[2]
		];
		const stalledRow = middleRows.find(text => text.includes('elapsed'));
		const crashedRow = middleRows.find(text => text.includes('Failed'));
		expect(stalledRow, 'The stalled run sorts between the ten-minute run and the three-hour run, whichever way the column points').toBeDefined();
		expect(crashedRow, 'The run that ended without storing a duration sorts between them too, by the hour it lasted').toBeDefined();
		expect(crashedRow, 'It shows exactly the hour between its start and its end').toMatch(EXACTLY_ONE_HOUR);
		expect(crashedRow, 'It has ended, so its time is not shown as still going').not.toContain('elapsed');
		expect(rowTexts[0], 'A finished run leads').not.toContain('elapsed');
		expect(rowTexts[3], 'A finished run closes').not.toContain('elapsed');
		testInfo.annotations.push({type: 'notes', description: rowTexts.map(text => text.replace(/\n/g, ' | ')).join(' || ')});
	});
});
