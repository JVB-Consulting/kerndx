// SPDX-License-Identifier: BUSL-1.1
const {test, expect} = require('@playwright/test');
const KernHomePage = require('../pages/kern-home.page');
const LogEntriesPage = require('../pages/log-entries.page');
const ScheduledJobsPage = require('../pages/scheduled-jobs.page');
const ApiTestHarnessPage = require('../pages/api-test-harness.page');
const ApiCallsPage = require('../pages/api-calls.page');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {getInstanceUrl} = require('../helpers/sf-auth');
const {soqlQuery, executeAnonymousApex} = require('../helpers/sf-cli');
const {namespacePrefix} = require('../helpers/sf-namespace');

const BATCH_DRAIN_ATTEMPTS = 36;
const BATCH_DRAIN_INTERVAL_MS = 5000;
const SEED_POLL_ATTEMPTS = 12;
const SEED_POLL_INTERVAL_MS = 2500;

/**
 * Waits out any running kern batch (the suite's own fire-and-forget purge included) so a row seeded
 * afterwards cannot be deleted from under a test. Bounded: after about three minutes the caller proceeds
 * regardless, so a leftover long-runner cannot deadlock the suite.
 */
async function waitForKernBatchesToDrain()
{
	for(let attempt = 0; attempt < BATCH_DRAIN_ATTEMPTS; attempt++)
	{
		const running = soqlQuery(
				'SELECT Id FROM AsyncApexJob WHERE JobType = \'BatchApex\' '
				+ 'AND Status IN (\'Holding\', \'Queued\', \'Preparing\', \'Processing\') '
				+ 'AND ApexClass.NamespacePrefix = \'kern\'');
		if(running.length === 0)
		{
			return;
		}
		await new Promise((resolve) => setTimeout(resolve, BATCH_DRAIN_INTERVAL_MS));
	}
}

/**
 * Polls for the log entry a test just seeded, by its unique short message, and returns its Id.
 * @param {string} seedMarker the unique short message the seed carried
 * @return {Promise<string|null>} the row's Id, or null when it never appeared
 */
async function pollForSeededLogEntry(seedMarker)
{
	for(let attempt = 0; attempt < SEED_POLL_ATTEMPTS; attempt++)
	{
		const rows = soqlQuery(`SELECT Id FROM kern__LogEntry__c WHERE kern__ShortMessage__c = '${seedMarker}' LIMIT 1`);
		if(rows.length > 0)
		{
			return rows[0].Id;
		}
		await new Promise((resolve) => setTimeout(resolve, SEED_POLL_INTERVAL_MS));
	}
	return null;
}

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
// Chain Watchdog fast-setup constants (V1j/V1k). The check name and the scheduler name are distinct
// Custom Labels (HealthCheck_ChainWatchdog_CheckName / _SchedulerName) that both currently read
// "Chain Watchdog" — kept as separate constants so a label change breaks only the assertion it affects.
const WATCHDOG_CHECK_NAME = 'Chain Watchdog';
const WATCHDOG_SCHEDULER_NAME = 'Chain Watchdog';
const WATCHDOG_CLASS_NAME = 'kern.SCHED_ChainWatchdog';
const WATCHDOG_DEFAULT_CRON = '0 0 * * * ?';
const WATCHDOG_DEFAULT_STALE_THRESHOLD_MINUTES = '30';
const WATCHDOG_DEFAULT_BATCH_SIZE = '50';
// V5: the label of the list view the package ships for calls whose status is Aborted (objects/ApiCall__c/listViews/Aborted).
const ABORTED_LIST_VIEW = 'Aborted';

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
		// Clear any leftover Chain Watchdog ScheduledJob from an interrupted prior run so V1j
		// starts from the warn baseline (its in-test tail cleanup only runs when it completes).
		executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'' + WATCHDOG_CLASS_NAME + '\'];');
		// Guarantee the Chain Abort Capability check's PASS precondition. The AsyncChainAbort
		// permission set ships assigned to nobody, so a pristine org WARNS on that check (a third
		// warn row beyond the two V1 asserts). The canonical cycle reaches part1 only after phase
		// 2's section 78 has granted the runner the permission set; scoped part1-only runs must not
		// depend on that ordering, so grant it idempotently here (same grant section 78a performs).
		executeAnonymousApex(
				'Id abortPermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = \'AsyncChainAbort\' AND NamespacePrefix = \'kern\'].Id; ' +
				'if([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :abortPermissionSetId] == 0) ' +
				'{ insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = abortPermissionSetId); }');
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

		// At this point the org warns on exactly two checks: Data Retention (no purge jobs) and
		// Chain Watchdog (no recovery job — the beforeAll delete guarantees that warn baseline).
		// Chain Abort Capability passes only because the beforeAll granted the runner the
		// AsyncChainAbort permission set; a truly pristine org would show it as a third warning.
		const actionItems = await home.getHealthCheckActionItems();
		expect(actionItems.length, 'Subscriber org at the part1 baseline should have exactly 2 health check warnings (Data Retention, Chain Watchdog)').toBe(2);
		const warningNames = actionItems.map(item => item.name);
		expect(warningNames.some(name => name.includes('Data Retention')), 'Data Retention should warn on a fresh org').toBeTruthy();
		expect(warningNames.some(name => name.includes(WATCHDOG_CHECK_NAME)), 'Chain Watchdog should warn on a fresh org').toBeTruthy();

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
				'kern.DTO_NameValues p = new kern.DTO_NameValues();'
					+ `p.add('objectName', '${objectName}');`
					+ 'p.add(\'minimumNumberOfDays\', \'90\');'
				+ 'insert new kern__ScheduledJob__c('
				+ `kern__SchedulerName__c = '${schedulerName}',`
				+ 'kern__ClassName__c = \'kern.SCHED_PurgeRecords\','
				+ 'kern__CronExpression__c = \'0 0 2 * * ?\','
				+ 'kern__IsActive__c = true,'
				+ 'kern__Parameters__c = p.serialize());');

		insertPurgeJob('kern__LogEntry__c', 'Purge Log Entries');

		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();
		await home.refreshHealthCheck();

		const partialItems = await home.getHealthCheckActionItems();
		expect(partialItems.length, 'Only Data Retention and Chain Watchdog should warn with 1 of 4 objects configured').toBe(2);
		const retentionItem = partialItems.find(item => item.name.includes('Data Retention'));
		expect(retentionItem, 'Data Retention should still warn with 1 of 4 objects configured').toBeTruthy();
		expect(retentionItem.detail, 'Should not mention Log Entry after its purge job is created').not.toContain('Log Entry');
		expect(retentionItem.detail, 'Should still mention API Call').toContain('API Call');

		insertPurgeJob('kern__ApiCall__c', 'Purge API Calls');
		insertPurgeJob('kern__ApiIssue__c', 'Purge API Issues');
		insertPurgeJob('kern__AsyncChainExecution__c', 'Purge Chain Executions');

		await home.refreshHealthCheck();

		const remainingItems = await home.getHealthCheckActionItems();
		expect(remainingItems.length, 'Only the Chain Watchdog warning should remain when all 4 purge jobs are configured').toBe(1);
		expect(remainingItems[0].name, 'The remaining warning should be Chain Watchdog, proving Data Retention passes').toContain(WATCHDOG_CHECK_NAME);

		executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\'];');
	});

	test('V1d: Apply Recommended Retention creates all four purge jobs', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		// Page-error tripwire (see V1e): the Apply modal is equally exposed to lightning-modal
		// lifecycle throws — a label-less open crashed it in real browsers while e2e stayed green.
		const pageErrors = [];
		page.on('pageerror', (error) => pageErrors.push(String(error.message)));

		await home.clickApplyRetention();
		await home.confirmApplyRetention();
		expect(pageErrors, `The apply-retention flow must not throw page errors (got: ${JSON.stringify(pageErrors)})`).toEqual([]);

		const jobs = soqlQuery('SELECT kern__SchedulerName__c, kern__Parameters__c FROM kern__ScheduledJob__c '
				+ 'WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\' ORDER BY kern__SchedulerName__c');
		expect(jobs.length, 'Four purge jobs should have been created').toBe(4);

		await home.refreshHealthCheck();
		const remainingItems = await home.getHealthCheckActionItems();
		expect(remainingItems.length, 'Only the Chain Watchdog warning should remain after apply').toBe(1);
		expect(remainingItems[0].name, 'The remaining warning should be Chain Watchdog, proving Data Retention passes').toContain(WATCHDOG_CHECK_NAME);

		executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'kern.SCHED_PurgeRecords\'];');
	});

	test('V1e: Customize each job opens prefilled editor and persists per-object saves', async({page}) =>
	{
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		// Page-error tripwire: the blank-modal regression threw inside lightning-modal's
		// renderedCallback ("e.trim is not a function" when the modal's label is not a string).
		// Sterile automation survives the throw (no mid-open re-render), so visibility checks
		// alone stay green — the uncaught error is the only universal symptom.
		const pageErrors = [];
		page.on('pageerror', (error) => pageErrors.push(String(error.message)));

		await home.clickCustomizeRetention();
		expect(await home.retentionSubRows().count(), 'Four sub-rows should render').toBe(4);

		await home.setUpButton('kern__LogEntry__c').click();
		const editor = page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: 15_000});
		expect(pageErrors, `Opening the Set-up editor must not throw page errors (got: ${JSON.stringify(pageErrors)})`).toEqual([]);

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

		// Same page-error tripwire as V1e: a lightning-modal lifecycle throw leaves a dimmed
		// backdrop with no modal in real browsers, while sterile runs render anyway.
		const pageErrors = [];
		page.on('pageerror', (error) => pageErrors.push(String(error.message)));

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
		expect(pageErrors, `Opening the Set-up editor must not throw page errors (got: ${JSON.stringify(pageErrors)})`).toEqual([]);
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
				'Customize flow must not emit "Unable to access Apex type" errors: schedulerClassName is now forwarded from Apex, '
				+ `so any such error indicates a namespace-resolution regression (found: ${JSON.stringify(apexTypeErrors)})`).toEqual([]);

		const iconWarnings = consoleMessages.filter(m => /invalid icon name/i.test(m.text));
		expect(iconWarnings,
				'Customize flow must emit no "<lightning-icon> Invalid icon name" warnings: commit 62b2147 eliminated the disabled-combobox source, '
				+ `so any such warning is a regression (found: ${JSON.stringify(iconWarnings)})`).toEqual([]);
	});

	test('V1j: Schedule Chain Watchdog one-click creates the recommended hourly job', async({page}) =>
	{
		// Feature lands in 1.6.0-2: the subscriber org still runs the 1.6.0-1 package, which has no
		// Chain Watchdog health check — this test goes green once the org is upgraded to 1.6.0-2.
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		// Page-error tripwire (see V1e): the watchdog confirm dialogue is a lightning-modal and is
		// equally exposed to lifecycle throws that sterile automation survives while real browsers crash.
		const pageErrors = [];
		page.on('pageerror', (error) => pageErrors.push(String(error.message)));

		const watchdogRowName = home.healthCheck().locator('[data-testid="health-check-name"]', {hasText: WATCHDOG_CHECK_NAME}).first();
		await expect(watchdogRowName, 'Chain Watchdog warn row must render on an org with no watchdog job scheduled').toBeVisible();
		await expect(home.scheduleWatchdogButton(), 'Schedule Chain Watchdog button must render on the warn row').toBeVisible();

		await home.scheduleWatchdogButton().click();
		await home.watchdogConfirmRoot().waitFor({state: 'visible', timeout: 15_000});
		await expect(home.watchdogConfirmSchedule(), 'Schedule picklist must render inside the confirm dialogue').toBeVisible();

		// Keep the default schedule: the proposal's recommended hourly cron must arrive preselected.
		const preselectedCron = await home.watchdogConfirmSchedule().evaluate((el) => el.value);
		expect(preselectedCron, 'Confirm dialogue must preselect the recommended hourly cron').toBe(WATCHDOG_DEFAULT_CRON);

		await home.watchdogCreateButton().click();
		await home.watchdogConfirmRoot().waitFor({state: 'hidden', timeout: 15_000});
		expect(pageErrors, `The one-click schedule flow must not throw page errors (got: ${JSON.stringify(pageErrors)})`).toEqual([]);

		// V1d's post-apply style, hardened: the create + re-run round-trip completes after the modal
		// closes, so refresh until the row flips to a passing chip before asserting the created record.
		await home.refreshUntilHealthCheckPosture(WATCHDOG_CHECK_NAME, 'pass');
		await expect(home.healthCheckPassingChip(WATCHDOG_CHECK_NAME), 'Chain Watchdog must render as a passing chip after the one-click schedule').toBeVisible();

		const jobs = soqlQuery('SELECT kern__SchedulerName__c, kern__CronExpression__c, kern__IsActive__c, kern__Parameters__c '
				+ `FROM kern__ScheduledJob__c WHERE kern__ClassName__c = '${WATCHDOG_CLASS_NAME}'`);
		expect(jobs.length, 'Exactly one Chain Watchdog scheduled job should have been created').toBe(1);
		expect(jobs[0].kern__SchedulerName__c, 'The job must carry the recommended scheduler name').toBe(WATCHDOG_SCHEDULER_NAME);
		expect(jobs[0].kern__IsActive__c, 'The watchdog job must be created active').toBe(true);
		expect(jobs[0].kern__CronExpression__c, 'Keeping the default must persist the recommended hourly cron').toBe(WATCHDOG_DEFAULT_CRON);
		expect(jobs[0].kern__Parameters__c, 'Parameters must carry the recommended stale threshold')
		.toMatch(new RegExp(`"StaleThresholdMinutes"\\s*:\\s*"${WATCHDOG_DEFAULT_STALE_THRESHOLD_MINUTES}"`));
		expect(jobs[0].kern__Parameters__c, 'Parameters must carry the recommended batch size')
		.toMatch(new RegExp(`"BatchSize"\\s*:\\s*"${WATCHDOG_DEFAULT_BATCH_SIZE}"`));

		// Deleting the ScheduledJob__c fires its before-delete trigger, which also aborts the platform
		// CronTrigger job — the org returns to the watchdog warn baseline for later tests.
		executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'' + WATCHDOG_CLASS_NAME + '\'];');
	});

	test('V1k: Customize schedule opens the watchdog-prefilled editor and Cancel creates nothing', async({page}) =>
	{
		// Feature lands in 1.6.0-2: the subscriber org still runs the 1.6.0-1 package, which has no
		// Chain Watchdog health check — this test goes green once the org is upgraded to 1.6.0-2.
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		// Page-error tripwire (see V1e/V1g): opening the prefilled editor is the same lightning-modal
		// lifecycle surface whose throws crash real browsers while sterile automation stays green.
		const pageErrors = [];
		page.on('pageerror', (error) => pageErrors.push(String(error.message)));

		await home.customizeWatchdogLink().click();

		const editor = page.locator('[data-testid="scheduled-job-editor-root"]');
		await editor.waitFor({state: 'visible', timeout: 15_000});
		expect(pageErrors, `Opening the customize editor must not throw page errors (got: ${JSON.stringify(pageErrors)})`).toEqual([]);

		// The Scheduler Name field carries no data-testid — it is the first lightning-input in the
		// editor grid (the locked Class Name input is second and carries data-testid="class-name").
		const schedulerNameInput = editor.locator('lightning-input').first().locator('input');
		expect(await schedulerNameInput.inputValue(), 'Scheduler Name must be prefilled from the watchdog proposal').toBe(WATCHDOG_SCHEDULER_NAME);

		const classNameField = editor.locator('[data-testid="class-name"]');
		const tag = await classNameField.evaluate((el) => el.tagName.toLowerCase());
		expect(tag, 'Locked mode must render lightning-input (not lightning-combobox)').toBe('lightning-input');
		const isReadOnly = await classNameField.evaluate((el) => el.readOnly === true || el.getAttribute('read-only') !== null);
		expect(isReadOnly, 'Locked Class Name lightning-input must be read-only').toBe(true);
		expect(await classNameField.locator('input').inputValue(), 'Locked Class Name must show the namespaced watchdog class').toBe(WATCHDOG_CLASS_NAME);

		const staleThresholdInput = editor.locator('[data-testid="param-StaleThresholdMinutes"] input');
		expect(await staleThresholdInput.inputValue(), 'Stale threshold parameter must be prefilled with the recommended default').toBe(WATCHDOG_DEFAULT_STALE_THRESHOLD_MINUTES);
		const batchSizeInput = editor.locator('[data-testid="param-BatchSize"] input');
		expect(await batchSizeInput.inputValue(), 'Batch size parameter must be prefilled with the recommended default').toBe(WATCHDOG_DEFAULT_BATCH_SIZE);

		// V1e clicks footer buttons via evaluate — the modal footer sits outside the body root and
		// can be off-viewport in headless runs.
		const cancelButton = page.locator('[data-testid="cancel-button"]').first();
		await cancelButton.evaluate((el) => el.click());
		await expect(editor, 'Editor root should be hidden after Cancel').toBeHidden({timeout: 15_000});
		expect(pageErrors, `The cancel flow must not throw page errors (got: ${JSON.stringify(pageErrors)})`).toEqual([]);

		const jobs = soqlQuery('SELECT Id FROM kern__ScheduledJob__c WHERE kern__ClassName__c = \'' + WATCHDOG_CLASS_NAME + '\'');
		expect(jobs.length, 'Cancel must not create a Chain Watchdog scheduled job').toBe(0);
	});

	test('V2: Log Entry List and Record', async({page}) =>
	{
		// The suite's beforeAll fires a fire-and-forget purge of kern__LogEntry__c. On a cold org that batch can
		// still be deleting while this test runs, and a row taken from "the newest entries" then vanishes
		// mid-render (the record opened without its tabs on the 1.7 upgrade leg). So: wait out any running
		// kern batch, seed one entry of our own, and open that one.
		await waitForKernBatchesToDrain();
		const seedMarker = `e2e-part1-v2-${Date.now()}`;
		executeAnonymousApex(
				'insert new kern__LogEntry__c(kern__LogLevel__c = \'INFO\', kern__ShortMessage__c = \'' + seedMarker + '\', '
				+ 'kern__Message__c = \'Part 1 V2 seed row\', kern__ClassMethod__c = \'PartOneAppCore.v2\', kern__LineNumber__c = 1, '
				+ 'kern__ExecutionEvent__c = \'SYNCHRONOUS\', kern__UserId__c = UserInfo.getUserId());');
		const seededId = await pollForSeededLogEntry(seedMarker);
		expect(seededId, 'the seeded LogEntry__c row should be queryable').toBeTruthy();
		test.info().annotations.push({type: 'notes', description: `opened the seeded log entry ${seededId}`});

		const instanceUrl = getInstanceUrl();
		await page.goto(`${instanceUrl}/lightning/r/kern__LogEntry__c/${seededId}/view`, {waitUntil: 'domcontentloaded'});
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

		// The seeded row is written directly, so it carries no origin or source, and it cannot be stamped here: a run
		// against an older installed version has neither field. Remove it, so every entry left in the org names its writer.
		executeAnonymousApex('delete [SELECT Id FROM kern__LogEntry__c WHERE kern__ShortMessage__c = \'' + seedMarker + '\'];');
	});

	test('V3: Scheduled Job Lifecycle + Timezone', async({page}) =>
	{
		const leftover = soqlQuery('SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c LIKE \'E2E %\'');
		for(const record of leftover)
		{
			executeAnonymousApex('delete [SELECT Id FROM kern__ScheduledJob__c WHERE Id = \'' + record.Id + '\'];');
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
		await harness.selectService('Query Pwnd Passwords (REST)');
		await expect.poll(() => harness.requiredParameterKeys(), {timeout: 10_000, message: 'The declared required input should be seeded as a locked row'}).toEqual(['password']);
		expect(await harness.isExecuteEnabled(), 'Execute must wait for the required value').toBe(false);
		expect((await harness.recordIdLabel()).trim(), 'A service that needs no record shows the field as optional').toContain('(optional)');
		await harness.setParameter(0, null, 'Password123');
		expect(await harness.isExecuteEnabled(), 'A filled required value enables Execute').toBe(true);
		await harness.reset();

		await harness.selectDirection('Outbound');
		await harness.selectService('Echo Subscriber Service');
		await expect.poll(() => harness.isExecuteEnabled(),
				{timeout: 10_000, message: 'Echo declares no required input, so Execute enables once the service description has landed'}).toBe(true);
		expect((await harness.recordIdLabel()).trim(), 'Echo declares no triggering record, so its Record ID reads optional too').toContain('(optional)');
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

		// The package ships an Aborted list view on API Calls: the record first, then what the picker offers.
		const abortedViews = soqlQuery(`SELECT Id FROM ListView WHERE SobjectType = '${namespacePrefix()}ApiCall__c' AND DeveloperName = 'Aborted'`);
		expect(abortedViews.length, 'Expected the Aborted list view on API Calls').toBe(1);
		const apiCalls = new ApiCallsPage(page);
		expect(await apiCalls.isListViewOffered(ABORTED_LIST_VIEW), 'Expected the API Calls list-view picker to offer Aborted').toBe(true);
	});
});
