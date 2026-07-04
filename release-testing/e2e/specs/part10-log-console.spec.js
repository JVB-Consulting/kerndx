// SPDX-License-Identifier: BUSL-1.1
//
// Part 10: Log Console (V106-V113).
//
// The console's Apex plumbing (CTRL_LogConsole and the read layer under it) is public, not global,
// so no subscriber Apex test can reach it — this spec is the only subscriber-context proof of the
// whole Log Console stack, including the Chain Monitor "View logs" cross-link whose bare
// `apiName: 'LogConsole'` must resolve to the namespaced `kern__LogConsole` nav item (the same
// defect class part1's V1c guards for the launcher tiles).
//
// Data: seed-log-console.apex (one coherent shaped story: a registered fulfilment chain, a
// correlated-but-unregistered request, recurring problems, calendar/straddle rows) layered with
// seed-log-console-bulk.apex (paging volume, SOSL body-only and correlation search tokens). Both
// are namespace-robust and idempotent; teardown-log-console.apex removes every seeded row.
//
// PREREQUISITE (V108 hard-gates on it): audit-field back-dating must be enabled in the org —
// Settings:Security enableAuditFieldsInactiveOwner first, THEN the CreateAuditFields permission
// set, as two separate deploys. See RUNBOOK Phase 1 and the seed script's header. The seed emits
// `auditBackdate=OK|FAILED_ENABLE_AUDIT_FIELDS` and this spec records which it saw.
const path = require('path');
const {test, expect} = require('@playwright/test');
const LogConsolePage = require('../pages/log-console.page');
const ChainMonitorPage = require('../pages/chain-monitor.page');
const KernHomePage = require('../pages/kern-home.page');
const {navigateToApp, waitForPageLoad} = require('../helpers/sf-navigation');
const {runApexScript, soqlQuery} = require('../helpers/sf-cli');

const SEED_SCRIPT = path.join(__dirname, '..', '..', 'scripts', 'seed-log-console.apex');
const BULK_SEED_SCRIPT = path.join(__dirname, '..', '..', 'scripts', 'seed-log-console-bulk.apex');
const TEARDOWN_SCRIPT = path.join(__dirname, '..', '..', 'scripts', 'teardown-log-console.apex');

const CHAIN_CORRELATION = 'e2e-corr-fulfil';
const SYNC_CORRELATION = 'e2e-corr-sync';
const PAGE_SIZE = 50;

// Set by beforeAll from the shaped seed's own probe output.
let seedBackdateOk = false;

// Local-date formatter for the custom-range date inputs (yyyy-mm-dd in the viewer's timezone —
// the console interprets the custom range in local time, so UTC-shifted toISOString is wrong here).
function toLocalDateInput(date)
{
	const pad = (value) => String(value).padStart(2, '0');
	return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function daysAgo(days)
{
	const date = new Date();
	date.setDate(date.getDate() - days);
	return date;
}

test.describe.serial('Part 10: Log Console', () =>
{
	test.beforeAll(async() =>
	{
		test.setTimeout(600_000);

		// part1 (scheduler-serial project, which this project depends on) launches a
		// fire-and-forget kern__LogEntry__c purge batch in its beforeAll. Wait out any
		// still-running kern batch before seeding so the purge cannot delete the fixtures
		// mid-spec. Bounded: after ~3 minutes we proceed regardless (the purge has then
		// almost certainly drained; a leftover long-runner should not deadlock the suite).
		for(let attempt = 0; attempt < 36; attempt++)
		{
			const running = soqlQuery(
					'SELECT Id FROM AsyncApexJob WHERE JobType = \'BatchApex\' '
					+ 'AND Status IN (\'Holding\', \'Queued\', \'Preparing\', \'Processing\') '
					+ 'AND ApexClass.NamespacePrefix = \'kern\'');
			if(running.length === 0)
			{
				break;
			}
			await new Promise((resolve) => setTimeout(resolve, 5000));
		}

		const seedResult = runApexScript(SEED_SCRIPT, {timeout: 300_000});
		expect(seedResult.raw, 'Shaped seed should report SEED_LOG_CONSOLE').toContain('SEED_LOG_CONSOLE');
		seedBackdateOk = /auditBackdate=OK/.test(seedResult.raw);

		const bulkResult = runApexScript(BULK_SEED_SCRIPT, {timeout: 300_000});
		expect(bulkResult.raw, 'Bulk seed should report SEED_LOG_CONSOLE_BULK').toContain('SEED_LOG_CONSOLE_BULK');
	});

	test.afterAll(() =>
	{
		test.setTimeout(300_000);
		runApexScript(TEARDOWN_SCRIPT, {timeout: 300_000});
	});

	test('V106: Launcher tile opens the namespaced Log Console tab and the view toggle switches lists', async({page}) =>
	{
		test.setTimeout(180_000);
		await navigateToApp(page, 'Kern');
		const home = new KernHomePage(page);
		await home.navigate();

		await expect(home.toolCard('logConsole'), 'Kern Home should render the Log Console launcher tile').toBeVisible();
		await home.launchTool('logConsole');
		await waitForPageLoad(page);

		const console = new LogConsolePage(page);
		expect(page.url(), `Launcher tile should navigate to the namespaced nav item ${console.tabApiName()}`)
		.toContain(`/lightning/n/${console.tabApiName()}`);

		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();

		// Problem summary is the default view; its list carries the grouped-problem columns.
		expect(await console.isViewActive('problems'), 'Problem summary should be the active default view').toBeTruthy();
		let headers = await console.getColumnHeaderText();
		expect(headers, 'Problems view should show the Count column').toContain('Count');
		expect(headers, 'Problems view should show the Last seen column').toContain('Last seen');
		expect(await console.getRowCount(), 'Problems view should render grouped problems from the seed').toBeGreaterThan(0);

		// Individual entries swaps the columns to the forensic-row shape.
		await console.switchView('entries');
		expect(await console.isViewActive('entries'), 'Individual entries should activate on toggle').toBeTruthy();
		headers = await console.getColumnHeaderText();
		expect(headers, 'Entries view should show the Time column').toContain('Time');
		expect(headers, 'Entries view should show the Correlation column').toContain('Correlation');
		expect(await console.getRowCount(), 'Entries view should render forensic rows from the seed').toBeGreaterThan(0);

		await console.switchView('problems');
		expect(await console.isViewActive('problems'), 'Toggling back should restore Problem summary').toBeTruthy();
	});

	test('V107: Ribbon summary cards, severity filter, and top-source drilldown', async({page}) =>
	{
		test.setTimeout(180_000);
		const console = new LogConsolePage(page);
		await console.navigate();

		// Default levels are ERROR + WARN: total card, one card per active level, top sources.
		const initialCards = await console.summaryCards().count();
		expect(initialCards, 'Ribbon should render total, per-level, and top-source cards').toBeGreaterThanOrEqual(3);
		await expect(console.levelCard('ERROR'), 'Error level card should render for the default filter').toBeVisible();
		await expect(console.levelCard('WARN'), 'Warning level card should render for the default filter').toBeVisible();

		// The approximate badge only appears when the server capped the rollup window — record
		// what this run saw instead of forcing a state a live org cannot guarantee.
		const approximate = await console.approximateBadge().isVisible().catch(() => false);
		test.info().annotations.push({type: 'notes', description: `Totals-approximate badge visible: ${approximate}`});

		// Enabling INFO via the severity segmented control adds its ribbon card.
		await console.setLevel('INFO', true);
		expect(await console.levelPressed('INFO'), 'INFO toggle should read pressed after enabling').toBeTruthy();
		await expect(console.levelCard('INFO'), 'Info level card should appear once INFO is enabled').toBeVisible();

		// Clicking a level card narrows the filter to that single level.
		await console.levelCard('ERROR').click();
		await console.waitForListSettled();
		expect(await console.levelPressed('ERROR'), 'ERROR should stay pressed after the card drill').toBeTruthy();
		expect(await console.levelPressed('WARN'), 'WARN should unpress when the Error card narrows the filter').toBeFalsy();
		expect(await console.levelPressed('INFO'), 'INFO should unpress when the Error card narrows the filter').toBeFalsy();

		// A ranked top-source row drills the list via the search box.
		const sourceCount = await console.sourceRows().count();
		expect(sourceCount, 'Top sources card should list at least one ranked source').toBeGreaterThan(0);
		const drilledSource = await console.sourceRows().first().getAttribute('data-source');
		await console.sourceRows().first().click();
		await console.waitForListSettled();
		expect(await console.searchValue(), 'Source drill should pin the source into the search box').toBe(drilledSource);

		await console.clearAll();
		expect(await console.searchValue(), 'Clear all should empty the search box').toBe('');
		expect(await console.levelPressed('WARN'), 'Clear all should restore the WARN default').toBeTruthy();
	});

	test('V108: Date-range presets and custom range window the list correctly', async({page}) =>
	{
		test.setTimeout(240_000);

		// HARD GATE: without audit-field back-dating every seeded CreatedDate silently snapped to
		// "now" and every window assertion below would pass vacuously or fail misleadingly.
		expect(seedBackdateOk,
				'Audit-field back-dating is not enabled in this org (seed reported FAILED_ENABLE_AUDIT_FIELDS). '
				+ 'Run the two-step recipe in RUNBOOK Phase 1 (Security settings first, then the CreateAuditFields '
				+ 'permission set) and re-seed before running V108.').toBeTruthy();

		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();
		// The calendar probes are INFO rows whose short messages carry a unique token, so the
		// immediate SOQL short-message search leg (no SOSL index lag) pins exactly those rows.
		await console.search('Calendar probe');

		// Today: only the 00:30-local row; the 23:30-yesterday straddle row must stay out.
		await console.selectDateRange('Today');
		let texts = await console.getRowTexts();
		expect(texts.some((text) => text.includes('today 00:30 local')), 'Today should include the 00:30-local probe').toBeTruthy();
		expect(texts.some((text) => text.includes('midnight straddle')), 'Today must exclude the 23:30-yesterday straddle probe').toBeFalsy();

		// Yesterday: the straddle row and the noon row, nothing else.
		await console.selectDateRange('Yesterday');
		texts = await console.getRowTexts();
		expect(texts.some((text) => text.includes('midnight straddle')), 'Yesterday should include the straddle probe').toBeTruthy();
		expect(texts.some((text) => text.includes('yesterday noon local')), 'Yesterday should include the noon probe').toBeTruthy();
		expect(texts.some((text) => text.includes('today 00:30 local')), 'Yesterday must exclude the today probe').toBeFalsy();

		// Last 7 days: rolling window keeps the recent probes and drops the eight-day-old one.
		await console.selectDateRange('Last 7 days');
		texts = await console.getRowTexts();
		expect(texts.some((text) => text.includes('today 00:30 local')), 'Last 7 days should include the today probe').toBeTruthy();
		expect(texts.some((text) => text.includes('eight days ago')), 'Last 7 days must exclude the eight-day-old probe').toBeFalsy();

		// Custom range spanning days 9 to 7 back surfaces ONLY the eight-day-old probe.
		await console.selectDateRange('Custom range…');
		await console.setCustomRange({
			fromDate: toLocalDateInput(daysAgo(9)), fromTime: '00:00', toDate: toLocalDateInput(daysAgo(7)), toTime: '23:59'
		});
		texts = await console.getRowTexts();
		expect(texts.some((text) => text.includes('eight days ago')), 'The custom range should surface the eight-day-old probe').toBeTruthy();
		expect(texts.some((text) => text.includes('today 00:30 local')), 'The custom range must exclude the today probe').toBeFalsy();
		test.info().annotations.push({type: 'notes', description: `Custom-range rows: ${texts.length}`});
	});

	test('V109: Endless scroll loads pages past the first fifty rows', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');

		// The bulk seed guarantees far more matching rows than one page even on the default
		// ERROR + WARN 24-hour window.
		const initialRows = await console.getRowCount();
		expect(initialRows, `First load should fill exactly one page of ${PAGE_SIZE} rows`).toBe(PAGE_SIZE);

		let grownTo = initialRows;
		for(let attempt = 0; attempt < 5 && grownTo <= initialRows; attempt++)
		{
			await console.scrollTableToBottom();
			grownTo = await console.getRowCount();
		}
		test.info().annotations.push({type: 'notes', description: `Rows after endless scroll: ${initialRows} -> ${grownTo}`});
		expect(grownTo, 'Scrolling to the bottom should append the next page').toBeGreaterThan(initialRows);
	});

	test('V110: Column sorting re-orders the entries server-side', async({page}) =>
	{
		test.setTimeout(180_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');

		const beforeRows = await console.getRowTexts();
		const beforeFirst = beforeRows[0]?.substring(0, 60);

		// The entries default is Time descending (newest first); the header click flips to
		// ascending, so with seed data spanning days the first row must change.
		await console.clickColumnHeader('Time');

		const afterRows = await console.getRowTexts();
		const afterFirst = afterRows[0]?.substring(0, 60);
		expect(afterRows.length, 'Rows should still render after the sort').toBeGreaterThan(0);
		expect(afterFirst, 'First row should change when Time flips to ascending').not.toBe(beforeFirst);
		test.info().annotations.push({type: 'notes', description: `Before: ${beforeFirst} | After: ${afterFirst}`});
	});

	test('V111: Debounced search narrows by correlation token and by body-only SOSL match', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();

		// Correlation tokens go through the SOQL LIKE leg — immediate, no search-index lag.
		await console.search('MANGOLARK');
		let texts = await console.getRowTexts();
		expect(texts.length, 'The MANGOLARK correlation token should match the seeded row').toBeGreaterThanOrEqual(1);
		expect(texts.some((text) => text.includes('Checkout step recorded')), 'The correlation match should be the seeded checkout row').toBeTruthy();

		// APRICOTSWIFT lives ONLY in Message__c/StackTrace__c, so it can only match through the
		// SOSL body leg — which depends on the org's search index having caught up with the seed.
		// Poll briefly; when the index is still cold, record that instead of failing the release
		// run on platform indexing latency.
		await console.search('APRICOTSWIFT');
		texts = await console.getRowTexts();
		for(let attempt = 0; attempt < 5 && texts.length === 0; attempt++)
		{
			await page.waitForTimeout(6000);
			// Re-filling the identical term fires no change event, so clear first to force a
			// fresh server query against the (possibly just-caught-up) search index.
			await console.search('');
			await console.search('APRICOTSWIFT');
			texts = await console.getRowTexts();
		}
		if(texts.length > 0)
		{
			expect(texts.some((text) => text.includes('Unhandled exception in handler')),
					'The body-only SOSL match should be the seeded handler-exception row').toBeTruthy();
			test.info().annotations.push({type: 'notes', description: 'SOSL body-only search matched'});
		}
		else
		{
			const empty = await console.emptyState().isVisible().catch(() => false);
			expect(empty, 'A zero-hit body search should render the empty state, not a broken list').toBeTruthy();
			test.info().annotations.push({type: 'notes', description: 'SOSL body-only search returned no rows (search index not yet caught up) — verify manually if this persists across the run'});
		}
	});

	test('V112: Chain Monitor "View logs" cross-links to the console and round-trips back', async({page}) =>
	{
		test.setTimeout(240_000);
		const monitor = new ChainMonitorPage(page);
		await monitor.navigate();

		// The seeded fulfilment chain; when newer part7/part8 chains push it off the top of the
		// list, a Started sort re-orders and one more scan finds it.
		let rows = await monitor.getRowTexts();
		let chainIndex = rows.findIndex((text) => text.includes('Order Fulfilment'));
		if(chainIndex < 0)
		{
			await monitor.clickColumnHeader('Started');
			rows = await monitor.getRowTexts();
			chainIndex = rows.findIndex((text) => text.includes('Order Fulfilment'));
		}
		expect(chainIndex, 'The seeded Order Fulfilment chain should be listed in the Chain Monitor').toBeGreaterThanOrEqual(0);
		await monitor.selectRow(chainIndex);

		// The button navigates with the bare apiName 'LogConsole' — this click is the proof that
		// the platform resolves it to the namespaced nav item in a subscriber org.
		const viewLogs = monitor.getDetailPanel().locator('[data-testid="view-logs"]').first();
		await expect(viewLogs, 'The chain detail should offer the View logs cross-link').toBeVisible();
		await viewLogs.click();
		await waitForPageLoad(page);

		const console = new LogConsolePage(page);
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		expect(page.url(), 'View logs should land on the namespaced Log Console nav item').toContain(`/lightning/n/${console.tabApiName()}`);
		await console.waitForListSettled();

		// The deep link pins the chain's correlation as a removable pill and lands on entries.
		await expect(console.correlationPill(), 'The correlation deep link should render as a pill').toBeVisible();
		expect(await console.correlationPill().innerText(), 'The pill should carry the chain correlation id').toContain(CHAIN_CORRELATION);
		expect(await console.isViewActive('entries'), 'A correlation deep link should land on Individual entries').toBeTruthy();
		expect(await console.getRowCount(), 'All four chain hops should list under the pinned correlation').toBe(4);

		// Round trip: the drawer's Open in Chain Monitor goes back with the same correlation.
		await console.selectRow(0);
		await console.detailPanel().waitFor({state: 'visible', timeout: 15_000});
		await expect(console.chainButton(), 'A registered chain should surface Open in Chain Monitor').toBeVisible();
		await console.chainButton().click();
		await waitForPageLoad(page);
		expect(page.url(), 'Open in Chain Monitor should land on the namespaced Chain Monitor nav item').toContain('ChainMonitor');
		expect(page.url(), 'The round trip should carry the correlation id in the page state').toContain(CHAIN_CORRELATION);
	});

	test('V113: Detail drawer renders payload tabs, resolved user, and chain-gated timeline', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();

		// The recurring payment-timeout problem carries the full detail payload (message, stack,
		// context, governor limits).
		await console.search('Read timed out');
		const problemIndex = await console.findRowIndexByText('System.CalloutException: Read timed out');
		expect(problemIndex, 'The seeded payment-timeout problem should match the search').toBeGreaterThanOrEqual(0);
		await console.selectRow(problemIndex);
		await console.detailPanel().waitFor({state: 'visible', timeout: 15_000});

		// Severity badge paints: text plus an actual computed background (guards a lost CSS hookup).
		await expect(console.levelBadge(), 'The drawer should render the level badge').toBeVisible();
		expect(await console.levelBadge().innerText(), 'The badge should carry the ERROR level').toContain('ERROR');
		const badgeBackground = await console.levelBadge().evaluate((element) => window.getComputedStyle(element).backgroundColor);
		expect(badgeBackground, 'The ERROR badge should paint a real background colour').not.toBe('rgba(0, 0, 0, 0)');

		// Problems view shows the occurrence pill, and the originating user resolves to a display
		// name — a raw 005 id here means the server-side user resolution regressed.
		await expect(console.countPill(), 'The problems drawer should show the occurrence-count pill').toBeVisible();
		const userText = (await console.metaUser().innerText()).trim();
		expect(userText.length, 'The Details grid should show the originating user').toBeGreaterThan(0);
		expect(userText, 'The originating user should render as a resolved name, not a raw user id').not.toMatch(/^005\w{12,15}$/);

		// Overview payload, stack trace, context, and the governor-limit bars.
		await expect(console.messageCode(), 'Overview should render the message body').toBeVisible();
		expect(await console.limitBars().count(), 'Overview should render governor-limit bars for the seeded Limits payload').toBeGreaterThan(0);
		await console.openDrawerTab('Stack trace');
		await expect(console.stackCode(), 'The stack tab should render the stored trace').toBeVisible();
		expect(await console.stackCode().innerText(), 'The trace should carry the seeded client frames').toContain('PaymentGateway.capture');
		await console.openDrawerTab('Context');
		await console.openDrawerTab('Timeline');
		// This exemplar has no correlation id, so the timeline explains it stands alone.
		await expect(console.timelineNote(), 'An uncorrelated entry should carry the stands-alone note').toBeVisible();
		expect(await console.timelineNote().innerText(), 'The note should say the entry stands alone').toContain('stands alone');

		// Chain gating, negative side: the correlated quote validation shares a correlation id but
		// has NO registered chain, so the timeline renders while Open in Chain Monitor stays hidden.
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.search(SYNC_CORRELATION);
		expect(await console.getRowCount(), 'All three correlated quote-validation rows should match').toBe(3);
		await console.selectRow(0);
		await console.detailPanel().waitFor({state: 'visible', timeout: 15_000});
		expect(await console.chainButton().isVisible().catch(() => false),
				'A correlation without a registered chain must NOT offer Open in Chain Monitor').toBeFalsy();
		await console.openDrawerTab('Timeline');
		await expect(console.timelineGroups(), 'The correlated timeline should render its transaction groups').toBeVisible();
		expect(await console.timelineEntries().count(), 'The timeline should list the correlated hops').toBeGreaterThanOrEqual(3);
		await expect(console.timelineNote(), 'The not-a-registered-chain note should render').toBeVisible();
		expect(await console.timelineNote().innerText(), 'The note should explain there is no Chain Monitor view')
		.toContain('not a registered async chain');
	});
});
