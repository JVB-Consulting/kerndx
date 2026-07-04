// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const KernHomePage = require('../pages/kern-home.page');
const LogEntriesPage = require('../pages/log-entries.page');
const ScheduledJobsPage = require('../pages/scheduled-jobs.page');
const ApiCallsPage = require('../pages/api-calls.page');
const ApiTestHarnessPage = require('../pages/api-test-harness.page');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {soqlQuery, executeAnonymousApex} = require('../helpers/sf-cli');

const EXPECTED_TABS = [
	'Kern Home',
	'API Calls',
	'Log Entries',
	'Scheduled Jobs',
	'API Issues',
	'Login Frequencies',
	'Reports',
	'Dashboards'
];
const EXPECTED_TOOL_KEYS = [
	'apiTestHarness',
	'streamingMonitor',
	'chainMonitor',
	'dataMaskingAdvisor',
	'logConsole'
];

test.describe.serial('Part 1: App Home & Core Pages', () =>
{
	test.beforeAll(() =>
	{
		// Clear any leftover SCHED_PurgeRecords ScheduledJob records from prior runs so
		// V1b/V1d start from a known empty baseline (was previously inline in V1b/V1d).
		executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\'];');
		// Async-purge accumulated kern__LogEntry__c rows so a long-lived scratch org
		// doesn't hit STORAGE_LIMIT_EXCEEDED when V1b/V1d insert new ScheduledJob records.
		// Fire-and-forget batch — runs in the background while subsequent tests start.
		executeAnonymousApex('kern.UTIL_PurgeRecords.deleteAllRecords(\'kern__LogEntry__c\');');
	});

	test('V1: Kern App Home and Health Check', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		const tabs = await home.getNavTabs();
		for(const expected of EXPECTED_TABS)
		{
			expect(tabs.some(t => t.includes(expected)), `Nav bar should contain "${expected}" tab`).toBeTruthy();
		}

		await expect(home.healthCheck()).toBeVisible();
		for(const key of EXPECTED_TOOL_KEYS)
		{
			await expect(home.toolCard(key), `Tool card "${key}" should render under Administration Tools`).toBeVisible();
			await expect(home.toolLaunchButton(key), `Tool card "${key}" should have a launch button`).toBeVisible();
		}

		const actionItems = await home.getHealthCheckActionItems();
		expect(actionItems.length, 'Fresh subscriber org should have exactly 1 health check warning (Data Retention)').toBe(1);
		expect(actionItems[0].name).toContain('Data Retention');

		const warnSectionVisible = await home.warnSection().isVisible();
		expect(warnSectionVisible, 'Data Retention is a warn-tier check and must render inside the Review-recommended section').toBe(true);
		const failSectionVisible = await home.failSection().isVisible().catch(() => false);
		if(failSectionVisible)
		{
			const failBox = await home.failSection().boundingBox();
			const warnBox = await home.warnSection().boundingBox();
			expect(failBox.y, 'Action-required (fail) section must render above Review-recommended (warn) section in DOM order').toBeLessThan(warnBox.y);
		}

		await expect(home.applyRetentionButton(), 'Apply Recommended Retention button must render for the Data Retention check').toBeVisible();
		await expect(home.customizeRetentionLink(), 'Customize each job link must render for the Data Retention check').toBeVisible();
	});

	test('V1c: Administration tool cards launch namespaced tabs from Kern Home', async({page}) =>
	{
		test.setTimeout(180_000);
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);

		const expectedTabApiNames = {
			apiTestHarness: 'kern__ApiTestHarness',
			streamingMonitor: 'kern__StreamingEventMonitor',
			chainMonitor: 'kern__ChainMonitor',
			dataMaskingAdvisor: 'kern__DataMaskingAdvisor',
			logConsole: 'kern__LogConsole'
		};

		for(const [key, apiName] of Object.entries(expectedTabApiNames))
		{
			await home.navigate();
			await home.launchTool(key);
			await waitForPageLoad(page);
			expect(page.url(), `Tool card "${key}" should navigate to namespaced nav item "${apiName}" (not the unprefixed tab name)`).toContain(`/lightning/n/${apiName}`);
		}
	});

	test('V1b: Health Check Data Retention adapts when purge jobs are configured', async({page}) =>
	{
		const insertPurgeJob = (objectName, schedulerName) => executeAnonymousApex(
				'kern.DTO_NameValues p = new kern.DTO_NameValues();' + `p.add('objectName', '${objectName}');` + 'p.add(\'minimumNumberOfDays\', \'90\');'
				+ 'insert new kern__ScheduledJob__c(' + `kern__SchedulerName__c = '${schedulerName}',` + 'kern__ClassName__c = \'kern.SCHED_PurgeRecords\','
				+ 'kern__CronExpression__c = \'0 0 2 * * ?\',' + 'kern__IsActive__c = true,' + 'kern__Parameters__c = p.serialize());');

		insertPurgeJob('kern__LogEntry__c', 'Purge Log Entries');

		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();
		await home.refreshHealthCheck();

		const partialItems = await home.getHealthCheckActionItems();
		expect(partialItems.length, 'Should still warn with 1 of 4 objects configured').toBe(1);
		expect(partialItems[0].detail, 'Should not mention Log Entry after its purge job is created').not.toContain('Log Entry');
		expect(partialItems[0].detail, 'Should still mention API Call').toContain('API Call');

		insertPurgeJob('kern__ApiCall__c', 'Purge API Calls');
		insertPurgeJob('kern__ApiIssue__c', 'Purge API Issues');
		insertPurgeJob('kern__AsyncChainExecution__c', 'Purge Chain Executions');

		await home.refreshHealthCheck();

		const allPassing = await home.allHealthChecksPassing();
		expect(allPassing, 'All health checks should pass when all 4 purge jobs are configured').toBeTruthy();

		executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\'];');
	});

	test('V1d: Apply Recommended Retention creates all four purge jobs', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		await home.clickApplyRetention();
		await home.confirmApplyRetention();

		const jobs = soqlQuery('SELECT kern__SchedulerName__c, kern__Parameters__c FROM kern__ScheduledJob__c '
				+ 'WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\' ORDER BY kern__SchedulerName__c');
		expect(jobs.length, 'Four purge jobs should have been created').toBe(4);

		await home.refreshHealthCheck();
		const passing = await home.allHealthChecksPassing();
		expect(passing, 'Health check should be all green after apply').toBeTruthy();

		executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\'];');
	});

	test('V1e: Customize each job opens prefilled editor and persists per-object saves', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		await home.clickCustomizeRetention();
		expect(await home.retentionSubRows().count(), 'Four sub-rows should render').toBe(4);

		await home.setUpButton('kern__LogEntry__c').click();
		const editor = page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: 15_000});

		const objectInput = editor.locator('[data-testid="param-objectName"] input');
		expect(await objectInput.isEditable(), 'Object input should be read-only in locked mode').toBe(false);

		const saveBtn = page.locator('[data-testid="save-button"]').first();
		await saveBtn.evaluate((el) => el.click());
		await expect(editor, 'Editor root should be hidden after successful save').toBeHidden({timeout: 15_000});

		const saved = soqlQuery('SELECT kern__SchedulerName__c FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\'');
		expect(saved.length, 'One job should be saved after first Set up').toBe(1);

		await home.refreshHealthCheck();
		expect(await home.retentionSubRows().count(), 'Three unconfigured sub-rows should remain').toBe(3);

		const metaTexts = await home.getRetentionSubRowMetaTexts();
		for(const meta of metaTexts)
		{
			const match = meta.match(/^([\d,]+)\s+(record|records)\b/);
			expect(match, `Sub-row meta should lead with "N record(s)" (got: ${JSON.stringify(meta)})`).not.toBeNull();
			const count = Number(match[1].replace(/,/g, ''));
			const word = match[2];
			if(count === 1)
			{
				expect(word, `recordCount=1 must render "record" singular, not "records" (meta: ${JSON.stringify(meta)})`).toBe('record');
			}
			else
			{
				expect(word, `recordCount=${count} must render "records" plural (meta: ${JSON.stringify(meta)})`).toBe('records');
			}
		}

		executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\'];');
	});

	test('V1f: Customize-mode header renders headline, help, and back-to-apply link', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		await home.clickCustomizeRetention();

		await expect(home.customizeHeadline(), 'Customize-mode headline must be visible').toBeVisible();
		const headlineText = (await home.customizeHeadline().textContent()) || '';
		expect(headlineText, 'Customize-mode headline should interpolate numeric proposal count').toMatch(/customizing\s+\d+\s+job/i);

		await expect(home.customizeHelp(), 'Customize-mode help paragraph must be visible').toBeVisible();
		const helpText = (await home.customizeHelp().textContent()) || '';
		expect(helpText.trim().length, 'Customize help paragraph must not be empty').toBeGreaterThan(0);

		await expect(home.backToApplyLink(), 'Back-to-apply link must be visible in customize-mode header').toBeVisible();

		await home.clickBackToApply();
		await expect(home.applyRetentionButton(), 'Apply Recommended Retention button must re-appear after clicking back link').toBeVisible();
		await expect(home.customizeHeadline()).toBeHidden();
	});

	test('V1g: Set-up modal renders with usable dimensions, not the 32px empty shell', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		await home.clickCustomizeRetention();
		const setUpButton = home.setUpButton('kern__LogEntry__c');
		await setUpButton.waitFor({state: 'visible', timeout: 15_000});
		await setUpButton.click();

		const editor = page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: 15_000});

		const box = await editor.boundingBox();
		expect(box, 'Editor root must have a measurable bounding box').not.toBeNull();
		expect(box.height, `Modal body height must exceed 300px — the lightning-layout-inside-modal bug rendered a 32px shell (actual: ${box.height}px)`).toBeGreaterThan(300);
		expect(box.width, `Modal body width must exceed 500px for a usable form layout (actual: ${box.width}px)`).toBeGreaterThan(500);
	});

	test('V1h: Locked Class Name renders read-only input, not a combobox placeholder', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		await home.clickCustomizeRetention();
		await home.setUpButton('kern__LogEntry__c').click();

		const editor = page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: 15_000});

		const classNameField = editor.locator('[data-testid="class-name"]');
		await expect(classNameField, 'Class Name field must be present in the editor').toBeVisible();

		const tag = await classNameField.evaluate((el) => el.tagName.toLowerCase());
		expect(tag, 'Locked mode must render lightning-input (not lightning-combobox)').toBe('lightning-input');

		const fieldText = (await classNameField.textContent()) || '';
		expect(fieldText, 'Locked Class Name must not show the "Select a class..." combobox placeholder').not.toMatch(/select a class/i);

		const isReadOnly = await classNameField.evaluate((el) => el.readOnly === true || el.getAttribute('read-only') !== null);
		expect(isReadOnly, 'Locked Class Name lightning-input must be read-only').toBe(true);
	});

	test('V1i: Customize + Set-up flow emits no icon-name or Apex-type console warnings', async({page}) =>
	{
		const consoleMessages = [];
		page.on('console', (msg) =>
		{
			const type = msg.type();
			if(type === 'warning' || type === 'error')
			{
				consoleMessages.push({type, text: msg.text()});
			}
		});

		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		await home.clickCustomizeRetention();
		await home.setUpButton('kern__LogEntry__c').click();

		const editor = page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: 15_000});

		const apexTypeErrors = consoleMessages.filter(m => /unable to access apex type/i.test(m.text));
		expect(apexTypeErrors,
				`Customize flow must not emit "Unable to access Apex type" errors — schedulerClassName is now forwarded from Apex, so any such error indicates a namespace-resolution regression (found: ${JSON.stringify(
						apexTypeErrors)})`).toEqual([]);

		const iconWarnings = consoleMessages.filter(m => /invalid icon name/i.test(m.text));
		expect(iconWarnings,
				`Customize flow must emit no "<lightning-icon> Invalid icon name" warnings — commit 62b2147 eliminated the disabled-combobox source; any such warning is a regression (found: ${JSON.stringify(
						iconWarnings)})`).toEqual([]);
	});

	test('V2: Log Entry List and Record', async({page}) =>
	{
		const records = soqlQuery('SELECT Id, kern__LogLevel__c FROM kern__LogEntry__c ORDER BY CreatedDate DESC LIMIT 20');
		expect(records.length, 'LogEntry__c records should exist').toBeGreaterThan(0);

		const levels = new Set(records.map(r => r.kern__LogLevel__c).filter(Boolean));
		test.info().annotations.push({type: 'notes', description: `${records.length} log entries, levels: ${[...levels].join(', ')}`});

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__LogEntry__c/${records[0].Id}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);

		const logEntries = new LogEntriesPage(page);
		const recordTabs = await logEntries.getRecordTabs();
		const expectedTabs = [
			'Message',
			'Context',
			'Audit'
		];
		for(const tab of expectedTabs)
		{
			expect(recordTabs.some(t => t.includes(tab)), `Record should have "${tab}" tab`).toBeTruthy();
		}

		for(const tab of expectedTabs)
		{
			await logEntries.clickRecordTab(tab);
		}
	});

	test('V3: Scheduled Job Lifecycle + Timezone', async({page}) =>
	{
		const leftover = soqlQuery('SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c LIKE \'E2E %\'');
		for(const record of leftover)
		{
			executeAnonymousApex(`delete
            [
            SELECT Id
            FROM kern__ScheduledJob__c
            WHERE Id = '${record.Id}'];`);
		}

		await navigateToApp(page, 'Kern');
		const jobs = new ScheduledJobsPage(page);
		await jobs.navigate();

		await jobs.clickNew();
		await jobs.fillJobForm({
			name: 'E2E Lifecycle Test', className: 'SCHED_PurgeRecords', cron: '0 0 2 * * ?', parameters: {'objectName': 'kern__LogEntry__c'}
		});
		await jobs.clickSave();

		const detail = await jobs.getDetailComponent();
		await expect(detail).toBeVisible({timeout: 30_000});

		await jobs.clickEdit();
		const hasParams = await jobs.hasParameterInputs();
		expect(hasParams, 'Edit form should show parameter inputs').toBeTruthy();
		await jobs.clickCancel();

		await jobs.deleteCurrentRecord();

		await jobs.navigate();
		await jobs.clickNew();
		await jobs.fillJobForm({
			name: 'E2E Timezone Test', className: 'SCHED_PurgeRecords', cron: '0 0 14 * * ?', parameters: {'objectName': 'kern__LogEntry__c'}
		});
		await jobs.clickSave();

		const heading = await jobs.getScheduleHeading();
		expect(heading.length > 0, 'Schedule heading should display timezone').toBeTruthy();

		const cronDesc = await jobs.getCronDescription();
		expect(cronDesc.length > 0, 'Cron description should be present').toBeTruthy();

		await jobs.deleteCurrentRecord();
	});

	test('V4: API Test Harness — Launch from Kern Home, key-value parameters, Safe Mode execution', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		await home.launchTool('apiTestHarness');
		const harness = new ApiTestHarnessPage(page);
		await harness.waitForReady();

		expect(await harness.isEmptyResponseVisible(), 'Empty-response placeholder should render before first execution').toBeTruthy();

		const initialBadge = await harness.getModeBadgeLabel();
		expect(initialBadge?.trim(), 'Mode badge should default to Safe Mode').toContain('Safe Mode');

		await harness.selectDirection('Inbound');
		await harness.selectService('Subscriber Create Account');
		await harness.setBody('{"accountName":"E2E Harness Account","industry":"Technology"}');
		await harness.execute();

		expect(await harness.isResultVisible(), 'Inbound execution should render the response panel').toBeTruthy();
		const statusText = await harness.getStatusBadge();
		expect(statusText?.trim(), 'Status badge should show a non-empty status').toBeTruthy();

		await harness.reset();
		expect(await harness.isEmptyResponseVisible(), 'Reset should restore the empty-response placeholder').toBeTruthy();

		await harness.selectDirection('Outbound');
		await harness.selectService('Echo Subscriber Service');
		await harness.setParameter(0, 'key', 'value');
		await harness.addParameterRow();
		await harness.setParameter(1, 'note', 'e2e harness row');
		expect(await harness.parameterRowCount(), 'Add parameter row should append a second row').toBe(2);
		await harness.removeParameterRow(1);
		expect(await harness.parameterRowCount(), 'Remove parameter row should shrink back to one row').toBe(1);

		await harness.setMocking(true);
		await harness.execute();
		expect(await harness.isResultVisible(), 'Mocked outbound execution should render the response panel').toBeTruthy();
	});

	test('V5: API Call Records', async({page}) =>
	{
		let records = soqlQuery('SELECT Id, kern__ServiceName__c, kern__Status__c FROM kern__ApiCall__c ORDER BY CreatedDate DESC LIMIT 5');
		if(records.length === 0)
		{
			executeAnonymousApex('kern.API_Dispatcher.processInboundService(\'kern.API_Echo\');');
			records = soqlQuery('SELECT Id, kern__ServiceName__c, kern__Status__c FROM kern__ApiCall__c ORDER BY CreatedDate DESC LIMIT 5');
		}
		expect(records.length, 'ApiCall__c records should exist').toBeGreaterThan(0);

		test.info().annotations.push({type: 'notes', description: `${records.length} API call records found`});

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__ApiCall__c/${records[0].Id}/view`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);

		await expect(page.getByText('Service Name')).toBeVisible({timeout: 15_000});
		await expect(page.getByText('Status', {exact: true})).toBeVisible();
	});
});
