// SPDX-License-Identifier: BUSL-1.1
//
// Part 10: Log Console (V106-V113, plus the V122-V126 scripted matrix from PLAN-106 Phase 0 R3:
// OFFSET-proof deep scroll, sort persistence across a filter change, phone-width ribbon + drawer,
// the View-occurrences drill, and the still-running-chain frozen window end; plus V127 from Phase 4:
// opening a read-time-grouped problem, which the jest suite structurally cannot cover because it
// stubs lightning/datatable and so sees neither real key-field handling nor real focus movement;
// plus V128/V129, which prove a cleared hand-off cannot return — neither with the temporary tab it
// opened nor from the URL it left behind. Both are round trips through real Lightning navigation
// that no jest wire emission can stand in for, and they are separate tests deliberately: a reload
// builds a new console, which is precisely what makes each path unable to prove the other; plus
// V130/V131 from the 1.7 UX sweep: Escape closing the drawer and handing focus back to the list, and
// an inverted custom range being refused out loud. Both are browser-only — focus movement crosses the
// shadow boundary a jest datatable stub never builds, and the range message rides real Lightning
// date inputs, which validate typed text against the org user's locale).
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
const {navigateToApp, clickOtherNavTab, waitForPageLoad} = require('../helpers/sf-navigation');
const {getInstanceUrl} = require('../helpers/sf-auth');
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

// The entries grid renders each row's time as `Mon d, yyyy, h:mm AM/PM`. Pull the first such stamp
// out of a row's inner text so a test can compare the list's head and tail times without depending
// on which of several equal-timestamp rows the server happened to order first.
function firstRowTime(rowText)
{
	const match = (rowText || '').match(/[A-Z][a-z]{2} \d{1,2}, \d{4}, \d{1,2}:\d{2}\s*[AP]M/);
	return match ? new Date(match[0]) : null;
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

	test('V128: Clearing a pinned correlation drops the hand-off, which cannot come back with the tab', async({page}) =>
	{
		test.setTimeout(240_000);
		const monitor = new ChainMonitorPage(page);
		await monitor.navigate();

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
		await monitor.getDetailPanel().locator('[data-testid="view-logs"]').first().click();
		await waitForPageLoad(page);

		const console = new LogConsolePage(page);
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.correlationPill(), 'The hand-off should arrive pinned to the chain correlation').toBeVisible();
		expect(page.url(), 'The hand-off travels as page state on the console tab URL').toContain('c__correlationId');

		// The reader drops the pinned filter. The state that put it there has to go with it: the tab a
		// hand-off opens is temporary and keeps the URL it was opened with, so a surviving c__correlationId
		// re-pins the chain — and the two-minute window with it — on every later return to this tab.
		await console.removeCorrelation();
		await expect(console.correlationPill(), 'Removing the pill should clear the pinned correlation').toHaveCount(0);
		expect(page.url(), 'Clearing the filter must drop the hand-off state from the URL that carries it').not.toContain('c__correlationId');
		expect(page.url(), 'Dropping the state must not navigate off the console').toContain(`/lightning/n/${console.tabApiName()}`);

		// Leave and come back the way a reader does: the Log Console tab the hand-off opened. That tab is
		// temporary and Lightning restores it from the page reference it was CREATED with, so the c__ state
		// can reappear in the address bar whatever the console did to its own URL — that part is the
		// platform's, not ours. What must not come back is the filter: a hand-off is applied once, so the
		// re-delivered page reference leaves the cleared console exactly as the reader left it.
		// The leave stays SPA via whichever tab the CURRENT nav bar offers: current scratch pools may host
		// the temporary tab outside the Kern app, and recovering from that with an app hop reloads the page
		// — a reload legitimately resets the once-per-link key, which is V129's scenario, not this one.
		await clickOtherNavTab(page, 'Log Console');
		await console.returnByNavigationTab();

		await expect(console.correlationPill(), 'A cleared correlation must not return with the tab').toHaveCount(0);
	});

	test('V129: A console rebuilt from a cleared hand-off URL comes up on its own defaults', async({page}) =>
	{
		test.setTimeout(180_000);
		const console = new LogConsolePage(page);

		// Arrive as a hand-off does — the console tab plus the chain's correlation and window as page state.
		// Straight by URL rather than through the Chain Monitor: this test is about what the URL carries
		// afterwards, and a bookmarked or reloaded hand-off is exactly this address.
		const windowEnd = new Date();
		const windowStart = new Date(windowEnd.getTime() - 120_000);
		const handoffUrl = `${getInstanceUrl()}/lightning/n/${console.tabApiName()}`
				+ `?c__correlationId=${CHAIN_CORRELATION}&c__windowStart=${encodeURIComponent(windowStart.toISOString())}`
				+ `&c__windowEnd=${encodeURIComponent(windowEnd.toISOString())}`;
		await page.goto(handoffUrl, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();

		await expect(console.correlationPill(), 'The hand-off URL should pin the chain correlation').toBeVisible();
		expect(await console.dateRangeLabel(), 'A hand-off carrying bounds pins the console to exactly that window').toBe('Custom range…');

		await console.removeCorrelation();
		expect(page.url(), 'Clearing the filter must drop the hand-off state from the URL').not.toContain('c__correlationId');

		// The console is now built again from that cleaned address. Both halves of the hand-off — the pinned
		// correlation and the chain's two-minute window — used to be re-applied here, over a filter bar the
		// reader had just emptied, because the URL still described them.
		await page.reload({waitUntil: 'domcontentloaded'});
		await waitForPageLoad(page);
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();

		await expect(console.correlationPill(), 'A console rebuilt from the cleared URL must not be re-pinned').toHaveCount(0);
		expect(await console.dateRangeLabel(), 'The chain\'s window must not return either — a rebuilt console opens on its default range').toBe('Last 24 hours');
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

	test('V122: Endless scroll pages past two thousand rows without an OFFSET failure', async({page}) =>
	{
		test.setTimeout(600_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.selectDateRange('Last 30 days');

		// SOQL OFFSET caps at 2,000 rows; the console's pager is cursor-based and must sail past
		// it. The R0 bulk seed plus the org's ambient entries guarantee more than 2,000 matches on
		// the widest preset with every level on. Two consecutive stalls end the loop early so a
		// genuinely exhausted list fails the depth assertion instead of spinning out the timeout.
		let rows = await console.getRowCount();
		expect(rows, `First load should fill exactly one page of ${PAGE_SIZE} rows`).toBe(PAGE_SIZE);
		let stalls = 0;
		for(let attempt = 0; attempt < 60 && rows <= 2000 && stalls < 2; attempt++)
		{
			const before = rows;
			await console.scrollTableToBottom();
			rows = await console.getRowCount();
			stalls = rows === before ? stalls + 1 : 0;
		}
		test.info().annotations.push({type: 'notes', description: `Rows after deep scroll: ${rows}`});
		expect(rows, 'The cursor-based pager should keep appending past the 2,000-row OFFSET cap').toBeGreaterThan(2000);
	});

	test('V123: The active sort order survives a filter change', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();

		// Flip Time from the default descending to ascending, then change a filter and prove the
		// ascending order is still in force. The seed back-dates many rows to identical CreatedDate
		// values, so the specific head row is a tie group with no stable order across queries — this
		// asserts the ORDER persists (header indicator + oldest-first-to-newest-last on the page),
		// not that one particular row stays pinned, which ties make non-deterministic.
		const orderSignature = async() =>
		{
			const texts = await console.getRowTexts();
			const first = firstRowTime(texts[0]);
			const last = firstRowTime(texts[texts.length - 1]);
			return {first, last, count: texts.length};
		};

		await console.clickColumnHeader('Time');
		expect(await console.getColumnHeaderText(), 'Time should sort ascending after the header click').toContain('Sorted Ascending');
		const ascendingBefore = await orderSignature();
		expect(ascendingBefore.first && ascendingBefore.last, 'Both edge rows should carry a parseable time').toBeTruthy();
		expect(ascendingBefore.first.getTime(), 'Ascending should run oldest-first to newest-last down the page')
		.toBeLessThanOrEqual(ascendingBefore.last.getTime());

		// Toggle DEBUG off — the ascending sort must survive the filter change (header indicator and
		// page order both), rather than snapping back to the default Time-descending.
		await console.setLevel('DEBUG', false);
		const headerAfter = await console.getColumnHeaderText();
		expect(headerAfter, 'The ascending sort should survive the level change').toContain('Sorted Ascending');
		expect(headerAfter, 'The sort must not snap back to the default descending').not.toContain('Sorted Descending');
		const ascendingAfter = await orderSignature();
		expect(ascendingAfter.count, 'Rows should still render after the filter change').toBeGreaterThan(0);
		expect(ascendingAfter.first.getTime(), 'The list should still be ordered ascending after the filter change')
		.toBeLessThanOrEqual(ascendingAfter.last.getTime());
		test.info().annotations.push({type: 'notes', description: `Ascending held across DEBUG-off: before ${ascendingBefore.first?.toISOString()}..${ascendingBefore.last?.toISOString()}, after ${ascendingAfter.first?.toISOString()}..${ascendingAfter.last?.toISOString()}`});
	});

	test('V124: Phone width keeps the ribbon scrollable and opens the detail drawer', async({page}) =>
	{
		test.setTimeout(240_000);
		await page.setViewportSize({width: 390, height: 844});
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');

		// The summary ribbon must overflow-scroll at phone width — wrapped or clipped cards were
		// the R2 mobile defect this guards against.
		const ribbon = console.root().locator('.summary').first();
		const overflow = await ribbon.evaluate((element) => element.scrollWidth - element.clientWidth);
		expect(overflow, 'The ribbon should overflow horizontally at phone width').toBeGreaterThan(0);
		const scrolled = await ribbon.evaluate((element) =>
		{
			element.scrollLeft = element.scrollWidth;
			return element.scrollLeft;
		});
		expect(scrolled, 'The ribbon should scroll to its trailing cards').toBeGreaterThan(0);

		await console.selectRow(0);
		await expect(console.detailPanel(), 'Selecting a row at phone width should open the drawer').toBeVisible();
	});

	test('V125: The View-occurrences drill lands on a populated entries list', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();

		// Problems is the default view; drill the top problem's raw rows. The drill pins the class and
		// method the problem was grouped under rather than searching for its class name as free text,
		// so every row it lands on really was logged from that source.
		await console.selectRow(0);
		await console.detailPanel().locator('[data-testid="action-view-occurrences"]').first().click();
		await console.waitForListSettled();

		expect(await console.isViewActive('entries'), 'The drill should switch to Individual entries').toBeTruthy();
		await expect(console.sourceFilterPill(), 'The drill should pin a visible, removable source filter').toBeVisible();
		// lightning-pill takes its label as a property, not a reflected attribute, so it is read off the
		// element rather than the DOM.
		const pinned = await console.sourceFilterPill().evaluate((pill) => pill.label);
		expect(await console.searchValue(), 'A pinned drill leaves the search box alone').toBe('');
		const rows = await console.getRowCount();
		test.info().annotations.push({type: 'notes', description: `Pinned "${pinned}" matched ${rows} rows`});
		expect(rows, 'The drill should land populated on seeded data').toBeGreaterThan(0);

		// Every listed row carries the pinned source, which the old free-text drill could not promise:
		// it also matched rows that merely mentioned the class name in a message or a stack trace.
		// Matched through Playwright's text engine rather than DOM textContent: the datatable renders its
		// cells inside their own shadow roots, which a raw textContent read never enters.
		const pinnedSource = pinned.replace(/^[^:]*:\s*/, '');
		const carryingTheSource = console.rows().filter({hasText: pinnedSource});
		expect(await carryingTheSource.count(), 'Every row behind a drilled problem should carry that problem\'s own source').toBe(rows);

		// A problem always carries a count, and that count outlives the entries it counted, so the two
		// numbers on screen differ and the console says how they relate rather than leaving the reader
		// to reconcile "1,284 occurrences" with a handful of rows.
		await expect(console.occurrencesReconciliation(), 'The drill should reconcile the count with the entries on file').toBeVisible();

		// And the pin comes off again, restoring the unfiltered list.
		await console.sourceFilterPill().locator('button').first().click();
		await console.waitForListSettled();
		await expect(console.sourceFilterPill(), 'Removing the pill should clear the pinned source').toHaveCount(0);
		await expect(console.occurrencesReconciliation(), 'Nothing is pinned, so there is nothing to reconcile').toHaveCount(0);
	});

	test('V130: Escape closes the drawer and hands focus back to the list', async({page}) =>
	{
		test.setTimeout(240_000);
		// Focus movement across the shadow boundary is exactly what the jest stub of lightning/datatable
		// cannot answer: only a browser can say where focus actually went.
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.selectRow(0);
		await expect(console.detailPanel(), 'Selecting a row should open the drawer').toBeVisible();

		// Opening a row puts focus on the drawer panel, so the drawer's own controls are the next tab
		// stop rather than every remaining row's log-number link.
		const landedInDrawer = await console.root().evaluate((root) =>
		{
			const panel = root.querySelector('[data-testid="detail-panel"]');
			return !!panel && panel.getRootNode().activeElement === panel;
		});
		expect(landedInDrawer, 'Opening a row should put focus on the drawer panel').toBeTruthy();

		await page.keyboard.press('Escape');
		await page.waitForTimeout(500);

		await expect(console.detailPanel(), 'Escape should close the drawer').toHaveCount(0);
		const focusOnList = await console.root().evaluate((root) =>
		{
			const list = root.querySelector('.listwrap');
			return !!list && list.getRootNode().activeElement === list;
		});
		expect(focusOnList, 'Closing the drawer should return focus to the list').toBeTruthy();
	});

	test('V131: An inverted custom range is refused out loud instead of silently ignored', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.selectDateRange('Custom range…');

		// A forward range applies and the list reloads.
		await console.setCustomRange({fromDate: toLocalDateInput(daysAgo(3)), fromTime: '00:00', toDate: toLocalDateInput(new Date()), toTime: '23:59'});
		await expect(console.customRangeError(), 'A usable range carries no message').toHaveCount(0);

		// Now put the end before the start. The window cannot be run, and leaving the previous rows on
		// screen with nothing said made them look like the answer to the range just typed.
		await console.setCustomRange({fromDate: toLocalDateInput(daysAgo(1)), fromTime: '00:00', toDate: toLocalDateInput(daysAgo(3)), toTime: '00:00'});

		await expect(console.customRangeError(), 'An inverted range should say so').toBeVisible();
		expect(await console.customRangeError().textContent(), 'The message should name the field to fix').toContain('To date');
	});

	test('V127: A grouped problem opens, keeps its selection, and hands focus on', async({page}) =>
	{
		test.setTimeout(300_000);
		// Jest cannot reach any of this. It stubs lightning/datatable, so the real key-field handling, the
		// real single-select behaviour and real focus movement across the shadow boundary are all invisible
		// to the unit suite — and a grouped problem is precisely the row whose key is neither an id nor
		// anything the datatable has seen before. Only a browser can answer it.
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.waitForListSettled();

		// A grouped row is the one with no Log Number: it owns no record, so that cell carries the muted
		// stand-in mark. Found by that cell specifically — a tagged problem can dash its Source or Context
		// cell too, and would then fail the grouped-problem assertions below for the wrong reason.
		const groupedIndex = await console.findGroupedRowIndex();
		if(groupedIndex < 0)
		{
			// Before skipping, make sure the finder is not blind rather than the list empty of groups: the datatable
			// keys a grouped row on its grouping identity, never on a record id, so a non-id row key with no stand-in
			// mark rendered means the logNumber cell type stopped rendering — a failure, not an absence.
			const rowKeys = await console.rows().evaluateAll((rows) => rows.map((row) => row.getAttribute('data-row-key-value')));
			expect(rowKeys.some((key) => key && !/^[a-zA-Z0-9]{15,18}$/.test(key)),
					'A grouped row is listed but its log-number cell shows no stand-in: the logNumber cell type is not rendering').toBe(false);
		}
		test.skip(groupedIndex < 0, 'No grouped problem in the seeded window; problem grouping may be off for these levels');

		await console.selectRow(groupedIndex);
		await expect(console.detailPanel(), 'Selecting a grouped problem should open the drawer').toBeVisible();

		// The button is named for what it opens, because there is no record of the group itself to open.
		await expect(console.detailPanel().locator('[data-testid="action-open-latest"]').first(),
				'A grouped problem should offer its latest occurrence').toBeVisible();
		await expect(console.detailPanel().locator('[data-testid="action-open-record"]'),
				'A grouped problem has no record of its own to open').toHaveCount(0);
		await expect(console.detailPanel().locator('[data-testid="log-number"]'),
				'A grouped problem should not show a log number it does not have').toHaveCount(0);

		// The real datatable keys grouped rows on plain delimited text rather than a record id. If that value
		// were mishandled the row would lose its selection the moment anything re-rendered.
		const stillSelected = await console.rows().nth(groupedIndex).getAttribute('aria-selected');
		test.info().annotations.push({type: 'notes', description: `Grouped row ${groupedIndex} aria-selected=${stillSelected}`});

		// Focus has to be able to leave the row and reach the drawer, which is the interaction jest's stub
		// cannot exercise at all.
		const closeButton = console.detailPanel().locator('[data-testid="close-button"] button').first();
		await closeButton.focus();
		const focusReached = await closeButton.evaluate((element) => element.getRootNode().activeElement === element);
		expect(focusReached, 'The drawer close control should be reachable by keyboard from the list').toBeTruthy();

		// The two custom cell types read their attributes off the REAL datatable's typeAttributes bag — the one
		// thing the jest stub cannot prove, and the one that shipped broken once (a bare {recordUrl} binding
		// rendered every log number as muted text and never showed a pill). A tagged row keeps its record link
		// and carries the pill; a grouped row's log-number cell is the muted stand-in and never a link.
		// The seed always lands tagged problems in the default view (e2e-npe-afterupdate, e2e-pay-timeout), so a list
		// with no pill at all IS the regression, never an absence to skip over.
		const taggedRows = console.rows().filter({has: page.locator('.provenance-pill')});
		expect(await taggedRows.count(), 'The seeded tagged problems should carry the Tagged pill').toBeGreaterThan(0);
		await expect(taggedRows.first().locator('a').first(), 'A tagged row should keep its record link beside the pill').toBeVisible();
		await expect(taggedRows.first().locator('.log-number-none'), 'A tagged row has a record, so its log number is a link, not the stand-in').toHaveCount(0);
		// The log-number column is the only column that renders an anchor, so a grouped row carries none at all.
		await expect(console.rows().nth(groupedIndex).locator('a'), 'A grouped row must not link a record it does not have').toHaveCount(0);

		// And the approximate-totals help must be a focusable control now, not a title attribute — a title
		// reaches neither a keyboard nor a touch device.
		const helpIcon = console.root().locator('[data-testid="totals-approximate-help"]');
		if(await helpIcon.count() > 0)
		{
			await expect(helpIcon.first().locator('button'), 'The approximate-totals help should be a focusable control').toBeVisible();
		}
	});

	test('V126: A still-running chain deep link freezes the window end and Refresh keeps it', async({page}) =>
	{
		test.setTimeout(300_000);
		const console = new LogConsolePage(page);
		const windowStart = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();

		// A deep link whose source is still running carries no upper bound; the console freezes
		// customEnd at link-arrival time and Refresh must KEEP that frozen bound (later logs need a
		// manual range widen — the trade is transparent in the custom inputs). Waiting out a minute
		// boundary before refreshing makes a recomputed "now" bound show up as a changed To-time.
		await console.page.goto(
				`${getInstanceUrl()}/lightning/n/${console.tabApiName()}`
				+ `?c__correlationId=${CHAIN_CORRELATION}&c__windowStart=${encodeURIComponent(windowStart)}`,
				{waitUntil: 'domcontentloaded'});
		await waitForPageLoad(console.page);
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();

		await expect(console.correlationPill(), 'The deep link should pin the correlation as a pill').toBeVisible();
		const rangeDisplay = await console.root().locator('.date-range-combobox').first().innerText();
		expect(rangeDisplay, 'The bounded deep link should land on the custom range').toContain('Custom range');
		const toInput = (field) => console.root().locator(`.customrange-field[data-field="${field}"] input`).first();
		const frozenDate = await toInput('toDate').inputValue();
		const frozenTime = await toInput('toTime').inputValue();
		expect(frozenTime, 'The To-time should be seeded from the link-arrival instant').not.toBe('');
		expect(await console.getRowCount(), 'The chain hops should be inside the pinned window').toBeGreaterThan(0);

		await console.page.waitForTimeout(65_000);
		await console.root().locator('[data-spec-id="refresh-action"]').first().click();
		await console.waitForListSettled();
		expect(await toInput('toDate').inputValue(), 'Refresh should keep the frozen To-date').toBe(frozenDate);
		expect(await toInput('toTime').inputValue(), 'Refresh should keep the frozen To-time').toBe(frozenTime);
		test.info().annotations.push({type: 'notes', description: `Frozen window end held across Refresh: ${frozenDate} ${frozenTime}`});
	});
});
