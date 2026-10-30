// SPDX-License-Identifier: Apache-2.0
//
// Part 10: Log Console (V106-V113, plus the V122-V126 scripted matrix from the Log Console review:
// OFFSET-proof deep scroll, sort persistence across a filter change, phone-width ribbon + drawer,
// the View-occurrences drill, and the still-running-chain window end that Refresh moves; plus V127:
// opening a read-time-grouped problem, which the jest suite structurally cannot cover because it
// stubs lightning/datatable and so sees neither real key-field handling nor real focus movement;
// plus V128/V129, which prove a cleared hand-off cannot return — neither with the temporary tab it
// opened nor from the URL it left behind. Both are round trips through real Lightning navigation
// that no jest wire emission can stand in for, and they are separate tests deliberately: a reload
// builds a new console, which is precisely what makes each path unable to prove the other; plus
// V130/V131 from the 1.7 UX sweep: Escape closing the drawer and handing focus back to the list, and
// an inverted custom range being refused out loud. Both are browser-only — focus movement crosses the
// shadow boundary a jest datatable stub never builds, and the range message rides real Lightning
// date inputs, which validate typed text against the org user's locale); plus V154, a link into an action
// that is still running, whose window end moves on each Refresh and settles on the action's real end.
//
// The console's Apex plumbing (CTRL_LogConsole and the read layer under it) is public, not global,
// so no subscriber Apex test can reach it — this spec is the only subscriber-context proof of the
// whole Log Console stack, including the Chain Monitor "View logs" cross-link whose bare
// `apiName: 'LogConsole'` must resolve to the namespaced `kern__LogConsole` nav item (the same
// defect class part1's V1c guards for the launcher tiles).
//
// Data: seed-log-console.apex (one coherent shaped story: a registered fulfilment chain, a
// correlated-but-unregistered request, recurring problems, calendar/straddle rows) and its second part
// seed-log-console-actions.apex (the whole-action rows; helpers/log-console-seed.js runs both), layered with
// seed-log-console-bulk.apex (paging volume, SOSL body-only and correlation search tokens). All three
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
const {runApexScript, executeAnonymousApex, soqlQuery, waitForFrameworkBatchesToFinish} = require('../helpers/sf-cli');
const {runShapedSeed} = require('../helpers/log-console-seed');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {namespacePrefix} = require('../helpers/sf-namespace');
const {readShippedLabelValues} = require('../lib/shipped-labels');

const BULK_SEED_SCRIPT = path.join(__dirname, '..', '..', 'scripts', 'seed-log-console-bulk.apex');
const TEARDOWN_SCRIPT = path.join(__dirname, '..', '..', 'scripts', 'teardown-log-console.apex');

const CHAIN_CORRELATION = 'e2e-corr-fulfil';
const SYNC_CORRELATION = 'e2e-corr-sync';
const PAGE_SIZE = 50;

// The whole-action fixtures the shaped seed lays down: a checkout click that launched three chains
// (one of them nested under another), a nightly job with its restart clone, and a legacy action
// recorded before roots were tracked.
const ACTION_CHECKOUT = 'e2ee2ee2-0000-4000-8000-000000000a01';
const ACTION_NIGHTLY = 'e2ee2ee2-0000-4000-8000-000000000b01';
const CHAIN_NOTIFY = 'e2ee2ee2-0000-4000-8000-000000000a0b';
// The nightly job's restart clone: a run under the nightly action, so it belongs to no chain of the checkout action.
const CHAIN_NIGHTLY_RESTART = 'e2ee2ee2-0000-4000-8000-000000000b02';
const ACTION_LEGACY = 'e2ee2ee2-0000-4000-8000-000000000c01';
const UNKNOWN_ID = 'e2ee2ee2-0000-4000-8000-0000000000ff';
const ACTION_OWN_MESSAGE = 'Checkout launched three chains';

// V154's own action: one entry and one run still going, laid down by the journey itself and removed by it, because
// every action the shaped seed lays down has finished. The run is ended part-way through the journey.
const ACTION_FOLLOWING = 'e2ee2ee2-0000-4000-8000-000000000d01';
const CHAIN_FOLLOWING = 'e2ee2ee2-0000-4000-8000-000000000d02';
// How long V126 and V154 wait between two readings of the window end: past a second, the To-time input's finest step.
const FOLLOWING_READING_GAP_MILLISECONDS = 2000;
// The margin the console puts after an ended action's last entry when it sets the range to the action's lifetime.
const ACTION_RANGE_MARGIN_MILLISECONDS = 60_000;

// The two shaped-seed rows whose stored writer differs from the class name the engine recorded: a
// Flow logged as `Flow/Order Intake` and a component logged as `LWC/orderPanel.submitOrder`. They
// are the fixtures that tell a column reading the writer apart from one reading the class.
const FLOW_WRITER = 'Order Intake';
const COMPONENT_WRITER = 'orderPanel.submitOrder';
// Each of those two rows carries a message of its own, and the search for it is what puts the row on
// screen: both are back-dated by an hour or two, behind the hundreds of rows the bulk seed writes.
const FLOW_SEARCH_TERM = 'Order intake completed';
const COMPONENT_SEARCH_TERM = 'Submit retried after a slow save';
// The word two seeded writers say, `CartController` with `Checkout completed` and the Flow with its
// own line, so the sort has more than one name to order whichever rows the org holds.
const SORT_SEARCH_TERM = 'completed';
// The bridge prefixes the engine records in front of a Flow's or a component's location, which the
// Source column must never show as the writer's name.
const BRIDGE_PREFIXES = ['Flow.', 'Flow/', 'LWC.', 'LWC/'];
// The terminal hop of the seeded fulfilment run: an ERROR with a stack trace, context JSON and
// several transactions behind it, which is the drawer the hero capture opens too.
const TIMEOUT_MESSAGE = 'Read timed out';
// The glyphs the drawer's timeline used to stand in for an icon: a clock, an hourglass, a warning
// sign, a chevron and a corner arrow.
const TIMELINE_GLYPHS = /[⏱⏳⚠▶↳]/;
// The generic name every copy button shared before each one said what it copies.
const SHARED_COPY_LABEL = 'LogConsole_Copy';
// The spoken names of the two timeline icons that carry meaning no text beside them carries.
const TIMELINE_DURATION_LABEL = 'LogConsole_TimelineDuration';
const TIMELINE_WARNING_LABEL = 'LogConsole_TimelineWarning';

// The window the suite runs at (playwright.config.js), which the narrow pass puts back when it is done.
const WIDE_VIEWPORT_WIDTH = 1920;
const WIDE_VIEWPORT_HEIGHT = 1080;
// The two widths V135 narrows the console to with the drawer open, and its window height. At 1024 the
// drawer is still docked beside the list, which is the drawer at its narrowest; at 820 it takes the
// window over as an overlay. The timeline has to hold its shape at both.
const NARROW_DRAWER_WIDTHS = [1024, 820];
const NARROW_DRAWER_HEIGHT = 800;
// A resize lays the drawer out again, so nothing is measured until the browser has had a beat to finish.
const VIEWPORT_SETTLE_MILLISECONDS = 1000;
// A piece of a transaction head is on one line when its rendered height is no more than half again its
// own line height. A second line adds a whole line height, so a one-line piece lands under this bound
// with room for the slack a padding or a border adds, and a broken one lands well above it.
const ONE_LINE_HEIGHT_RATIO = 1.5;
// A computed line height of `normal` is not a number. Browsers lay `normal` out at about 1.2 times the
// font size, which stands in for it when an element leaves its line height unset.
const NORMAL_LINE_HEIGHT_RATIO = 1.2;
// How far a warning pin's centre may sit from the top-right corner of its own segment. The pin is
// pulled 0.39rem across and 0.42rem up against its own 0.875rem icon box, which at a 16 pixel root puts
// its centre within about a pixel of the corner; six pixels leaves room for rounding while still
// catching a pin that has slid off by anything like its own width.
const PIN_CORNER_TOLERANCE_PIXELS = 6;
// The half pixel a browser rounds a fractional device pixel by, allowed when one box must sit inside
// another.
const BOX_CONTAINMENT_SLACK_PIXELS = 0.5;
// How far the clock's centre may sit from the centre of the duration text beside it before the two are
// reading on different lines. A couple of pixels covers the difference between an icon box and a text
// box centred on one line, while a part that has dropped to a line of its own is a whole line away.
const ICON_TO_TEXT_CENTRE_TOLERANCE_PIXELS = 2;
// How far a part that has dropped to a row of its own may start from the edge the row above starts at.
// Both are the same computed edge, so only rounding separates them.
const ROW_START_TOLERANCE_PIXELS = 1.5;

// V111: the token the bulk seed writes only into one entry's message and stack trace, and that entry's writer.
const BODY_SEARCH_TOKEN = 'APRICOTSWIFT';
const BODY_SEARCH_SOURCE = 'OrderService';
// V111: the correlation token of a seeded entry by another writer (CartController), whose search ranks that writer.
const OTHER_WRITER_SEARCH_TERM = 'MANGOLARK';
// V111: two terms the search must read as plain text. The first ends in a star: read as a wildcard it would find the
// token's entry. The second joins two words of that entry's message with AND, in the opposite order to the message:
// read as an operator it would find the entry. No entry holds either text as written.
const WILDCARD_SEARCH_TERM = 'APRICOTSW*';
const OPERATOR_SEARCH_TERM = 'constraint AND APRICOTSWIFT';
// V111: the bulk seed's literal-search entry, whose message alone reads 'Quota PEARLFINCH*3 reached AND PEARLFINCH
// paused', and the two pieces of that message a search must find as written.
const LITERAL_ENTRY_MESSAGE = 'Literal search sample';
const LITERAL_STAR_SEARCH_TERM = 'PEARLFINCH*3';
const LITERAL_AND_SEARCH_TERM = 'reached AND PEARLFINCH';
const LITERAL_SEARCH_WAIT_MILLISECONDS = 30_000;
// The console's default window: the last 24 hours (DEFAULT_WINDOW_MINUTES in logConsole.js).
const DEFAULT_WINDOW_MILLISECONDS = 1440 * 60_000;
const BODY_FIELDS = ['ShortMessage__c', 'Message__c', 'StackTrace__c'];

// Set by beforeAll from the shaped seed's own probe output.
let seedBackdateOk = false;

/**
 * @description Counts, straight from the records, the individual entries a body search under one pinned writer must
 *              list: that writer's entries in the console's default window whose short message, message or stack
 *              trace holds the token anywhere in its text, even inside a longer word, in any letter case.
 *
 * @param {string} token The text searched for.
 * @param {string} source The pinned writer's name.
 * @param {string} origin The pinned row's origin; the drill sets the Origin filter to it unless it is MIXED.
 *
 * @returns {number} The number of entries the list must show.
 */
function countEntriesHoldingToken(token, source, origin)
{
	const prefix = namespacePrefix();
	const windowStart = new Date(Date.now() - DEFAULT_WINDOW_MILLISECONDS).toISOString().replace(/\.\d{3}Z$/, 'Z');
	const originClause = origin && origin !== 'MIXED' ? ` AND ${prefix}Origin__c = '${origin}'` : '';
	const fieldList = BODY_FIELDS.map((field) => `${prefix}${field}`).join(', ');
	const rows = soqlQuery(`SELECT ${fieldList} FROM ${prefix}LogEntry__c WHERE ${prefix}Source__c = '${source}'${originClause} `
			+ `AND ${prefix}OccurrenceCount__c = null AND CreatedDate >= ${windowStart}`);
	const needle = token.toUpperCase();
	return rows.filter((row) => BODY_FIELDS.some((field) => (row[`${prefix}${field}`] || '').toUpperCase().includes(needle))).length;
}

// The Apex that removes V154's action, its entries and its run, whatever state an earlier journey left them in.
function removeFollowingActionApex()
{
	return `delete [SELECT Id FROM kern__LogEntry__c WHERE kern__RootCorrelationId__c = '${ACTION_FOLLOWING}'];
delete [SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__RootCorrelationId__c = '${ACTION_FOLLOWING}'];`;
}

// The Apex that lays V154's action down: the entry the action wrote as it started, and one run still going under it.
// Any earlier copy goes first, so a journey that stopped before its own clean-up cannot change the next one.
function startFollowingActionApex()
{
	return `${removeFollowingActionApex()}
insert new kern__LogEntry__c(kern__LogLevel__c = 'INFO', kern__ClassMethod__c = 'E2EFollowingAction.start', kern__ShortMessage__c = 'Following action started',
		kern__CorrelationId__c = '${ACTION_FOLLOWING}', kern__RootCorrelationId__c = '${ACTION_FOLLOWING}');
insert new kern__AsyncChainExecution__c(kern__ChainName__c = 'E2E Following Action', kern__Status__c = 'Running', kern__CorrelationId__c = '${CHAIN_FOLLOWING}',
		kern__RootCorrelationId__c = '${ACTION_FOLLOWING}', kern__LaunchCorrelationId__c = '${ACTION_FOLLOWING}', kern__TotalSteps__c = 1,
		kern__CompletedSteps__c = 0, kern__StartedAt__c = System.now());`;
}

// The Apex that ends V154's action: the action writes its last entry and its run completes, so the summary reads it as ended.
function endFollowingActionApex()
{
	return `insert new kern__LogEntry__c(kern__LogLevel__c = 'INFO', kern__ClassMethod__c = 'E2EFollowingAction.finish', kern__ShortMessage__c = 'Following action finished',
		kern__CorrelationId__c = '${CHAIN_FOLLOWING}', kern__RootCorrelationId__c = '${ACTION_FOLLOWING}');
kern__AsyncChainExecution__c run = [SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__CorrelationId__c = '${CHAIN_FOLLOWING}'];
run.kern__Status__c = 'Completed';
run.kern__CompletedSteps__c = 1;
run.kern__CompletedAt__c = System.now();
update run;`;
}

// An instant as the custom-range inputs show it in a given time zone, date and time joined as yyyy-mm-ddThh:mm:ss, so two
// readings compare as text in time order.
function toRangeInputText(instant, timeZone)
{
	const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit',
		minute: '2-digit', second: '2-digit', hourCycle: 'h23'}).formatToParts(instant).map((part) => [part.type, part.value]));
	return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}`;
}

// The end of the console's custom range as its To inputs hold it, date and time joined as yyyy-mm-ddThh:mm:ss. Read off
// the components' own values rather than the text they render, so two readings compare as text in time order.
async function readRangeEnd(logConsole)
{
	const read = (name) => logConsole.root().locator(`.customrange-field[data-field="${name}"]`).first().evaluate((field) => field.value);
	return `${await read('toDate')}T${String(await read('toTime')).slice(0, 8)}`;
}

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

/**
 * @description Opens Individual entries with every level on and the widest window the shaped seed is
 *              read through, so the Flow and component rows it back-dates are on the page whatever
 *              hour the run starts at.
 */
async function openEntriesListOnTheWidestWindow(logConsole)
{
	await logConsole.navigate();
	await logConsole.switchView('entries');
	await logConsole.enableAllLevels();
	await logConsole.selectDateRange('Last 30 days');
	await logConsole.waitForListSettled();
}

/**
 * @description The Source cells that carry an origin pill, read twice: the whole cell, which carries
 *              the pill's own word after the writer, and the writer's own mark alone. Every cell with
 *              an origin has a name mark, so the two reads are counted against each other before
 *              either is judged, which keeps a later comparison from passing on an empty list.
 */
async function readNamedSourceCells(logConsole, page)
{
	const withOrigin = logConsole.sourceCells().filter({has: page.locator('[data-spec-id="entries-source-origin"]')});
	const namedCells = await withOrigin.allInnerTexts();
	const namedWriters = await logConsole.sourceCellNames().allInnerTexts();
	expect(namedWriters.length, 'Every source cell with an origin names its writer in its own mark').toBe(namedCells.length);
	return {namedCells, namedWriters};
}

/**
 * @description No cell that names an origin reads as the bridge path the engine recorded in front of
 *              a Flow's or a component's location.
 */
function assertNoBridgePathInAnyNamedSource(namedCells)
{
	for(const text of namedCells)
	{
		const cell = text.trim();
		expect(BRIDGE_PREFIXES.some((bridge) => cell.startsWith(bridge)), `A named source is a writer, not a bridge path: ${cell}`).toBeFalsy();
	}
}

/**
 * @description No writer's own mark reads as the bare namespace the framework's own classes live
 *              under, which is the check V142 makes of the Top sources card, made here of the list.
 */
function assertNoBareNamespaceInAnyNamedSource(namedWriters)
{
	for(const writer of namedWriters)
	{
		expect(writer.trim(), 'A named source is a writer, not a namespace').not.toBe(namespacePrefix().replace('__', ''));
	}
}

/**
 * @description Neither the bridge path nor the bare namespace reaches a cell that names an origin,
 *              read off whatever list is on screen: the unfiltered page or one narrowed by a search.
 */
async function assertEveryNamedSourceNamesItsWriter(logConsole, page)
{
	const named = await readNamedSourceCells(logConsole, page);
	assertNoBridgePathInAnyNamedSource(named.namedCells);
	assertNoBareNamespaceInAnyNamedSource(named.namedWriters);
}

/**
 * @description Every Source cell on the list names the same writer.
 */
function assertEveryCellNamesWriter(cellTexts, writer, message)
{
	for(const text of cellTexts)
	{
		const cell = text.trim();
		expect(cell.startsWith(writer), `${message}: ${cell}`).toBeTruthy();
	}
}

/**
 * @description Every origin pill on the list reads the same shipped word.
 */
function assertEveryPillReads(originTexts, originName, message)
{
	for(const text of originTexts)
	{
		expect(text, message).toBe(originName);
	}
}

/**
 * @description Narrows the list to one seeded line's own message and proves every row it lands on
 *              names that line's writer and its origin. The search is what puts these rows on screen
 *              at all: the shaped seed back-dates its Flow and component lines by an hour or two
 *              while the bulk seed writes hundreds of newer ones, so neither is ever on page one of
 *              the unfiltered list. The bridge and namespace checks run again here, because these are
 *              exactly the rows whose class name diverges from the writer that wrote them.
 */
async function assertSearchedWriterNamesEveryCell(logConsole, page, search)
{
	await logConsole.search(search.term);
	expect(await logConsole.getRowCount(), search.rowMessage).toBeGreaterThan(0);
	const cellTexts = await logConsole.sourceCells().allInnerTexts();
	assertEveryCellNamesWriter(cellTexts, search.writer, search.writerMessage);
	const originTexts = (await logConsole.sourceOriginPills().allInnerTexts()).map((text) => text.trim());
	expect(originTexts.length, search.pillMessage).toBe(cellTexts.length);
	assertEveryPillReads(originTexts, search.originName, search.originMessage);
	await assertEveryNamedSourceNamesItsWriter(logConsole, page);
}

/**
 * @description The writer names the list is showing right now, each cut at the first dot, slash or
 *              colon so a location reads as the name the column is ordered by.
 */
async function readSortedWriterNames(logConsole)
{
	return (await logConsole.sourceCellNames().allInnerTexts()).map((text) => text.trim().split(/[./:]/)[0]).filter((name) => name.length > 0);
}

/**
 * @description One page of writer names holds more than one name and is in the order asked for.
 */
function assertWriterNamesAreOrdered(names, ordering)
{
	expect(new Set(names).size, ordering.distinctMessage).toBeGreaterThan(1);
	const inOrder = [...names].sort(ordering.compare);
	expect(names, ordering.orderMessage).toEqual(inOrder);
}

/**
 * @description Sorts the list by the Source column both ways and proves each page is ordered by the
 *              writer's name. Read under a search that the seed answers with two writers of its own
 *              (`CartController` and `Order Intake`, which both log a line saying "completed"): the
 *              unfiltered list can hold fifty rows of one writer, which would prove nothing about the
 *              order, and its entries with no stored writer sort as one block at whichever end.
 *
 * @return {Promise<Object>} The names each direction listed, as `ascending` and `descending`.
 */
async function assertSourceColumnSortsByWriter(logConsole)
{
	await logConsole.search(SORT_SEARCH_TERM);
	expect(await logConsole.getRowCount(), 'The search the sort is read through lists the writers that answer it').toBeGreaterThan(0);
	await logConsole.clickColumnHeader('Source');
	expect(await logConsole.getColumnHeaderText(), 'The Source heading sorts the list ascending').toContain('Sorted Ascending');
	const ascending = await readSortedWriterNames(logConsole);
	assertWriterNamesAreOrdered(ascending, {distinctMessage: 'The ascending page holds more than one writer to order',
		orderMessage: 'The list sorts by the writer\'s name', compare: (left, right) => left.localeCompare(right, undefined, {sensitivity: 'base'})});
	await logConsole.clickColumnHeader('Source');
	expect(await logConsole.getColumnHeaderText(), 'A second click turns the Source sort around').toContain('Sorted Descending');
	const descending = await readSortedWriterNames(logConsole);
	assertWriterNamesAreOrdered(descending, {distinctMessage: 'The descending page holds more than one writer to order',
		orderMessage: 'Turned around, the list still sorts by the writer\'s name', compare: (left, right) => right.localeCompare(left, undefined, {sensitivity: 'base'})});
	return {ascending, descending};
}

/**
 * @description The icon name of every Lightning icon inside one mark of the drawer's timeline. The
 *              template compiler hands `icon-name` to the component as its `iconName` property and
 *              sets no attribute of that name, static or bound, so the property is read first and
 *              the attribute is only the fallback.
 */
async function iconNamesOf(holder)
{
	return holder.locator('lightning-icon').evaluateAll((icons) => icons.map((icon) => icon.iconName ?? icon.getAttribute('icon-name')));
}

/**
 * @description Whatever one mark of the drawer's timeline says to a screen reader, trimmed.
 */
async function assistiveTextOf(holder)
{
	return (await holder.locator('.slds-assistive-text').allInnerTexts()).map((text) => text.trim());
}

/**
 * @description Every element of a decorative mark carries its icon and says nothing: the text beside
 *              it already carries the meaning, so a screen reader must not hear the mark twice.
 */
async function assertSilentIcons(elements, count, mark)
{
	for(let index = 0; index < count; index++)
	{
		const holder = elements.nth(index);
		expect(await iconNamesOf(holder), mark.iconMessage).toContain(mark.iconName);
		expect(await assistiveTextOf(holder), mark.silentMessage).toEqual([]);
	}
}

/**
 * @description Every element of a meaningful mark carries its icon and says what it means, in the
 *              package's own shipped words.
 */
async function assertSpeakingIcons(elements, count, mark)
{
	for(let index = 0; index < count; index++)
	{
		const holder = elements.nth(index);
		expect(await iconNamesOf(holder), mark.iconMessage).toContain(mark.iconName);
		expect(await assistiveTextOf(holder), mark.spokenMessage).toContain(mark.spokenName);
	}
}

/**
 * @description Opens the entry the hero capture opens: the fulfilment run's terminal timeout, which
 *              carries a stack trace, context JSON and several transactions, so the drawer renders
 *              every mark at once, and lands on its Timeline tab.
 */
async function openTimelineForTimedOutHop(logConsole)
{
	await logConsole.navigate();
	await logConsole.switchView('entries');
	await logConsole.enableAllLevels();
	await logConsole.search(CHAIN_CORRELATION);
	const hopIndex = await logConsole.findRowIndexByText(TIMEOUT_MESSAGE);
	expect(hopIndex, 'The fulfilment run should list its timed-out hop').toBeGreaterThanOrEqual(0);
	await logConsole.selectRow(hopIndex);
	await expect(logConsole.detailPanel(), 'Opening the hop should open the drawer').toBeVisible();
	await logConsole.openDrawerTab('Timeline');
}

/**
 * @description Nothing on the drawer's timeline stands in for an icon with a character any more.
 */
async function assertTimelineShowsNoGlyphs(logConsole)
{
	expect(await logConsole.timelineGroups().innerText(), 'The transaction list shows icons, not glyphs').not.toMatch(TIMELINE_GLYPHS);
	expect(await logConsole.overviewStat().innerText(), 'The overview line shows icons, not glyphs').not.toMatch(TIMELINE_GLYPHS);
	expect(await logConsole.timelineMinimap().innerText(), 'The minimap shows icons, not glyphs').not.toMatch(TIMELINE_GLYPHS);
}

/**
 * @description Each mark on the drawer's timeline is the SLDS utility icon it stands for, and the two
 *              that carry meaning say what they mean out loud while the three decorative ones stay
 *              silent. The seeded run holds at least one crumb and at least one warning pin, so both
 *              counts are held above zero; a gap note only appears where the run really paused.
 */
async function assertTimelineMarksAreIcons(logConsole, labels)
{
	expect(await iconNamesOf(logConsole.overviewStat()), 'The overview line marks the run\'s duration with a clock').toContain('utility:clock');
	expect(labels[TIMELINE_DURATION_LABEL], 'The package ships a spoken name for the duration icon').toBeDefined();
	expect(await assistiveTextOf(logConsole.overviewStat()), 'The clock says what it means').toContain(labels[TIMELINE_DURATION_LABEL]);

	const chevronCount = await logConsole.transactionChevrons().count();
	expect(chevronCount, 'Each transaction is headed by a chevron').toBeGreaterThan(0);
	await assertSilentIcons(logConsole.transactionChevrons(), chevronCount,
			{iconName: 'utility:chevronright', iconMessage: 'A transaction chevron is an icon', silentMessage: 'A chevron is decoration, so it stays silent'});

	const crumbCount = await logConsole.transactionCrumbs().count();
	expect(crumbCount, 'The correlated run hands one transaction to the next, so it shows a crumb').toBeGreaterThan(0);
	await assertSilentIcons(logConsole.transactionCrumbs(), crumbCount,
			{iconName: 'utility:level_down', iconMessage: 'A hand-off crumb is an icon', silentMessage: 'A crumb is decoration, so it stays silent'});

	const warnPinCount = await logConsole.minimapWarnPins().count();
	expect(warnPinCount, 'The run logged a warning and an error, so the minimap pins one').toBeGreaterThan(0);
	expect(labels[TIMELINE_WARNING_LABEL], 'The package ships a spoken name for the warning icon').toBeDefined();
	await assertSpeakingIcons(logConsole.minimapWarnPins(), warnPinCount, {iconName: 'utility:warning',
		spokenName: labels[TIMELINE_WARNING_LABEL], iconMessage: 'A minimap warning is an icon', spokenMessage: 'The warning says what it means'});

	const gapCount = await logConsole.gapNotes().count();
	await assertSilentIcons(logConsole.gapNotes(), gapCount, {iconName: 'utility:hourglass', iconMessage: 'A gap in the run is marked by an hourglass icon',
		silentMessage: 'The gap note reads its own sentence, so its icon stays silent'});
}

/**
 * @description Clicking a transaction head opens or closes it, and its chevron turns with it.
 */
async function assertChevronTurnsWithItsTransaction(logConsole, page)
{
	const head = logConsole.transactionHeads().first();
	const expandedBefore = await head.getAttribute('aria-expanded');
	await head.click();
	await page.waitForTimeout(1000);
	const expandedAfter = await head.getAttribute('aria-expanded');
	expect(expandedAfter, 'Clicking a transaction head opens or closes it').not.toBe(expandedBefore);
	const chevronClass = await head.locator('[data-spec-id="transaction-chevron"]').first().getAttribute('class');
	expect(chevronClass, 'The chevron turns with the transaction it heads').toBe(expandedAfter === 'true' ? 'chev open' : 'chev');
}

/**
 * @description The rendered height of one piece of a transaction head, with the line height that piece
 *              was laid out with, both read from the browser rather than guessed. A computed line
 *              height of `normal` is not a number, so the element's own font size stands in for it at
 *              the ratio browsers lay `normal` out at.
 */
async function readLineFit(locator)
{
	return locator.evaluate((element, normalRatio) =>
	{
		const style = window.getComputedStyle(element);
		return {height: element.getBoundingClientRect().height, lineHeight: parseFloat(style.lineHeight) || parseFloat(style.fontSize) * normalRatio};
	}, NORMAL_LINE_HEIGHT_RATIO);
}

/**
 * @description One piece of a transaction head renders on a single line, measured against its own line
 *              height rather than assumed from the words in it.
 */
async function assertRendersOnOneLine(locator, message)
{
	const fit = await readLineFit(locator);
	expect(fit.height, `${message} (${fit.height.toFixed(1)} pixels tall against a line height of ${fit.lineHeight.toFixed(1)})`)
	.toBeLessThanOrEqual(fit.lineHeight * ONE_LINE_HEIGHT_RATIO);
}

/**
 * @description The rendered box of one element, in page pixels, with a check that it renders at all: a
 *              hidden element has no box, and an unread box would compare as nothing against anything.
 */
async function readRenderedBox(locator, message)
{
	const box = await locator.boundingBox();
	expect(box, message).not.toBeNull();
	return box;
}

/**
 * @description One rendered box sits inside another, give or take the half pixel a browser rounds a
 *              fractional device pixel by.
 */
function assertBoxSitsInside(inner, outer, message)
{
	expect(inner.x, `${message}: it starts left of its holder`).toBeGreaterThanOrEqual(outer.x - BOX_CONTAINMENT_SLACK_PIXELS);
	expect(inner.y, `${message}: it starts above its holder`).toBeGreaterThanOrEqual(outer.y - BOX_CONTAINMENT_SLACK_PIXELS);
	expect(inner.x + inner.width, `${message}: it runs past its holder's right edge`).toBeLessThanOrEqual(outer.x + outer.width + BOX_CONTAINMENT_SLACK_PIXELS);
	expect(inner.y + inner.height, `${message}: it runs past its holder's bottom edge`).toBeLessThanOrEqual(outer.y + outer.height + BOX_CONTAINMENT_SLACK_PIXELS);
}

/**
 * @description Every piece of one transaction head that must never break mid-piece stays on a line of
 *              its own: the offset, the duration beside it, and, where the head carries one, the crumb
 *              naming the transaction that handed this one its work.
 */
async function assertHeadPiecesStayWhole(logConsole, head, index, width)
{
	const mark = `At ${width} pixels wide, transaction ${index}`;
	await assertRendersOnOneLine(logConsole.transactionOffset(head), `${mark}'s offset reads on one line`);
	await assertRendersOnOneLine(logConsole.transactionDuration(head), `${mark}'s duration reads on one line`);
	const crumb = logConsole.transactionCrumb(head);
	if(await crumb.count() > 0)
	{
		await assertRendersOnOneLine(crumb.first(), `${mark}'s hand-off crumb reads on one line`);
	}
}

/**
 * @description Not one transaction head on the timeline breaks a piece of itself across two lines.
 */
async function assertNoTransactionHeadBreaksAPiece(logConsole, width)
{
	const heads = logConsole.transactionHeads();
	const count = await heads.count();
	expect(count, `At ${width} pixels wide the timeline still groups the run into transactions`).toBeGreaterThan(0);
	for(let index = 0; index < count; index++)
	{
		await assertHeadPiecesStayWhole(logConsole, heads.nth(index), index, width);
	}
}

/**
 * @description No transaction chevron is clipped by the width its wrapper reserves for it: the drawn
 *              icon sits inside the wrapper's own box.
 */
async function assertNoChevronIsClipped(logConsole, width)
{
	const chevrons = logConsole.transactionChevrons();
	const count = await chevrons.count();
	expect(count, `At ${width} pixels wide each transaction is still headed by a chevron`).toBeGreaterThan(0);
	for(let index = 0; index < count; index++)
	{
		const wrapper = chevrons.nth(index);
		const mark = `At ${width} pixels wide transaction ${index}'s chevron`;
		const icon = await readRenderedBox(logConsole.chevronIcon(wrapper), `${mark} draws its icon`);
		assertBoxSitsInside(icon, await readRenderedBox(wrapper, `${mark} has a box of its own`), `${mark} icon is clipped by its wrapper`);
	}
}

/**
 * @description One minimap segment's warning pin, where it carries one, hangs inside the minimap and
 *              centres on that segment's own top-right corner.
 *
 * @return {Promise<number>} 1 where the segment carried a pin, 0 where it carried none.
 */
async function assertWarningPinHangsOnItsCorner(logConsole, segment, minimapBox, mark)
{
	const pin = logConsole.segmentWarnPin(segment);
	const pinned = await pin.count() > 0;
	if(pinned)
	{
		const pinBox = await readRenderedBox(pin.first(), `${mark}'s warning pin renders`);
		const segmentBox = await readRenderedBox(segment, `${mark} renders`);
		assertBoxSitsInside(pinBox, minimapBox, `${mark}'s warning pin hangs outside the minimap`);
		const acrossFromCorner = Math.abs(pinBox.x + pinBox.width / 2 - segmentBox.x - segmentBox.width);
		const clearOfTheCorner = Math.abs(pinBox.y + pinBox.height / 2 - segmentBox.y);
		expect(acrossFromCorner, `${mark}'s warning pin sits ${acrossFromCorner.toFixed(1)} pixels across from its own top-right corner`)
		.toBeLessThanOrEqual(PIN_CORNER_TOLERANCE_PIXELS);
		expect(clearOfTheCorner, `${mark}'s warning pin sits ${clearOfTheCorner.toFixed(1)} pixels clear of its own top-right corner`)
		.toBeLessThanOrEqual(PIN_CORNER_TOLERANCE_PIXELS);
	}
	return pinned ? 1 : 0;
}

/**
 * @description Every warning pin on the minimap hangs on the corner of the segment it belongs to and
 *              inside the minimap's own bounds, and the seeded run still pins at least one segment.
 */
async function assertEveryWarningPinHangsOnItsCorner(logConsole, width)
{
	const minimapBox = await readRenderedBox(logConsole.timelineMinimap(), `At ${width} pixels wide the timeline still draws its minimap`);
	const segments = logConsole.minimapSegments();
	const count = await segments.count();
	let pinned = 0;
	for(let index = 0; index < count; index++)
	{
		pinned += await assertWarningPinHangsOnItsCorner(logConsole, segments.nth(index), minimapBox, `At ${width} pixels wide segment ${index}`);
	}
	expect(pinned, `At ${width} pixels wide the run's warning still pins a segment`).toBeGreaterThan(0);
}

/**
 * @description The overview line's own parts hold together: the counts and the duration each read on a
 *              single line, and the clock reads on the duration's line rather than drifting onto one of
 *              its own. The error clause is left out of this one because a long error is allowed to
 *              wrap as ordinary text; where it starts is the next check's business.
 */
async function assertOverviewStatPartsStayWhole(logConsole, width)
{
	const mark = `At ${width} pixels wide the overview line`;
	await assertRendersOnOneLine(logConsole.overviewStatCounts(), `${mark}'s counts read on one line`);
	await assertRendersOnOneLine(logConsole.overviewStatDuration(), `${mark}'s duration reads on one line`);
	const clock = await readRenderedBox(logConsole.overviewStatClock(), `${mark} draws its clock`);
	const duration = await readRenderedBox(logConsole.overviewStatDuration(), `${mark} shows its duration`);
	const apart = Math.abs(clock.y + clock.height / 2 - duration.y - duration.height / 2);
	expect(apart, `${mark}'s clock sits ${apart.toFixed(1)} pixels off the line its duration reads on`)
	.toBeLessThanOrEqual(ICON_TO_TEXT_CENTRE_TOLERANCE_PIXELS);
}

/**
 * @description A long error on the overview line may wrap as ordinary text, but it may not squeeze in
 *              beside the parts before it: once the line is taller than one line the error has to begin
 *              a row of its own, which it does when it starts at the edge the first part starts at. The
 *              error is read as the element carrying both the separator and the text where the console
 *              groups them, and as the text alone where it does not, so the check reads the same either
 *              way. Reading the grouped element is also what proves the separator is not stranded at the
 *              end of the row above: the separator is the first thing in it, so the clause's left edge
 *              is the separator's.
 */
async function assertOverviewErrorStartsItsOwnRow(logConsole, width)
{
	const clause = logConsole.overviewStatErrorClause();
	const errorPart = await clause.count() > 0 ? clause.first() : logConsole.overviewStatError().first();
	const statFit = await readLineFit(logConsole.overviewStat());
	if(await errorPart.count() > 0 && statFit.height > statFit.lineHeight * ONE_LINE_HEIGHT_RATIO)
	{
		const mark = `At ${width} pixels wide the overview line's error`;
		const errorBox = await readRenderedBox(errorPart, `${mark} renders`);
		const firstPart = await readRenderedBox(logConsole.overviewStatCounts(), `${mark} has a first part to line up under`);
		const indent = Math.abs(errorBox.x - firstPart.x);
		expect(indent, `${mark} starts ${indent.toFixed(1)} pixels in from where the line begins, so it never dropped to a row of its own`)
		.toBeLessThanOrEqual(ROW_START_TOLERANCE_PIXELS);
	}
}

/**
 * @description The drawer's timeline holds its shape at one width: the overview line keeps its parts
 *              whole, no transaction head breaks a piece of itself across two lines, no chevron is
 *              clipped by its wrapper, and every warning pin hangs on its own segment's corner inside
 *              the minimap.
 */
async function assertTimelineHoldsItsShape(logConsole, width)
{
	await assertOverviewStatPartsStayWhole(logConsole, width);
	await assertOverviewErrorStartsItsOwnRow(logConsole, width);
	await assertNoTransactionHeadBreaksAPiece(logConsole, width);
	await assertNoChevronIsClipped(logConsole, width);
	await assertEveryWarningPinHangsOnItsCorner(logConsole, width);
}

/**
 * @description The timeline holds its shape at each width V135 narrows the console to as well, and the
 *              window goes back where it was afterwards so the journeys that follow read the console at
 *              the width they were written for.
 */
async function assertTimelineHoldsItsShapeWhenNarrowed(logConsole, page)
{
	for(const width of NARROW_DRAWER_WIDTHS)
	{
		await page.setViewportSize({width, height: NARROW_DRAWER_HEIGHT});
		await page.waitForTimeout(VIEWPORT_SETTLE_MILLISECONDS);
		await expect(logConsole.timelineGroups(), `The drawer still shows its timeline at ${width} pixels wide`).toBeVisible();
		await assertTimelineHoldsItsShape(logConsole, width);
	}
	await page.setViewportSize({width: WIDE_VIEWPORT_WIDTH, height: WIDE_VIEWPORT_HEIGHT});
	await page.waitForTimeout(VIEWPORT_SETTLE_MILLISECONDS);
}

/**
 * @description One copy button says what it copies, in the tooltip a mouse finds and in the name a
 *              screen reader reads. Both are read from the rendered button rather than from the
 *              Lightning host, which carries neither.
 */
async function assertCopyButtonName(logConsole, testId, expected)
{
	expect(expected, `The package ships a name for the ${testId} button`).toBeDefined();
	const host = logConsole.copyButton(testId);
	expect(await host.count(), `The drawer renders the ${testId} button`).toBeGreaterThan(0);
	const button = host.locator('button').first();
	expect(await button.getAttribute('title'), `The ${testId} tooltip says what that button copies`).toBe(expected);
	const spoken = (await button.locator('.slds-assistive-text').first().innerText()).trim();
	expect(spoken, `The ${testId} button is read out by what it copies`).toBe(expected);
}

/**
 * @description The tooltip of every copy button the drawer is showing right now.
 */
async function collectCopyButtonNames(logConsole)
{
	return logConsole.detailPanel().locator('[data-testid^="copy-"] button')
	.evaluateAll((buttons) => buttons.map((button) => button.getAttribute('title')));
}

/**
 * @description Every copy button in the drawer says what it copies instead of the one word they all
 *              used to share, on each tab that renders one.
 */
async function assertEveryCopyButtonSaysWhatItCopies(logConsole, labels)
{
	expect(labels[SHARED_COPY_LABEL], 'The shared copy name is still shipped, retired from use but never retired from the file').toBeDefined();
	const sharedNames = [];
	await logConsole.openDrawerTab('Overview');
	await assertCopyButtonName(logConsole, 'copy-message', labels.LogConsole_CopyMessage);
	await assertCopyButtonName(logConsole, 'copy-correlation', labels.LogConsole_CopyCorrelation);
	sharedNames.push(...await collectCopyButtonNames(logConsole));
	await logConsole.openDrawerTab('Stack trace');
	await assertCopyButtonName(logConsole, 'copy-stack', labels.LogConsole_CopyStackTrace);
	sharedNames.push(...await collectCopyButtonNames(logConsole));
	await logConsole.openDrawerTab('Context');
	await assertCopyButtonName(logConsole, 'copy-context', labels.LogConsole_CopyContext);
	sharedNames.push(...await collectCopyButtonNames(logConsole));
	expect(sharedNames, 'No copy button in the drawer still carries the name they all shared').not.toContain(labels[SHARED_COPY_LABEL]);
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
		await waitForFrameworkBatchesToFinish();

		const seedResult = runShapedSeed();
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
		// The whole-action work replaced the Correlation column with Chain, which names the run rather than
		// repeating its raw id; the correlation itself is still in the drawer, where V113 and V133 read it.
		expect(headers, 'Entries view should show the Chain column').toContain('Chain');
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

		// A ranked top-source row pins the list to exactly that writer: a removable pill, the search box untouched,
		// and the Origin filter set to the row's origin, so the card and the list count the same rows.
		const sourceCount = await console.sourceRows().count();
		expect(sourceCount, 'Top sources card should list at least one ranked source').toBeGreaterThan(0);
		const drilledSource = await console.sourceRows().first().getAttribute('data-source');
		const drilledOrigin = await console.sourceRows().first().getAttribute('data-origin');
		expect(drilledOrigin, 'Every ranked source names its origin').toMatch(/^(FRAMEWORK|APEX|FLOW|COMPONENT|MIXED)$/);
		await console.sourceRows().first().click();
		await console.waitForListSettled();
		expect(await console.searchValue(), 'A source drill never types into the search box').toBe('');
		await expect(console.sourceFilterPill(), 'A source drill pins a visible, removable source filter').toBeVisible();
		expect(await console.sourceFilterPill().evaluate((pill) => pill.label), 'The pill names the drilled source').toContain(drilledSource);
		if(drilledOrigin !== 'MIXED')
		{
			expect(await console.originFilterValue(), 'The Origin filter follows the drilled row').toBe(drilledOrigin);
		}

		await console.clearAll();
		expect(await console.searchValue(), 'Clear all should empty the search box').toBe('');
		expect(await console.levelPressed('WARN'), 'Clear all should restore the WARN default').toBeTruthy();

		// The card's count is the list's count: in Individual entries a ranked row carries its own row count,
		// so drilling it must leave the ribbon's total on exactly that number.
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.waitForListSettled();
		const rankedMetric = await console.sourceRows().first().locator('.metric').innerText();
		const rankedCount = Number(rankedMetric.replace(/\D/g, ''));
		expect(rankedCount, 'A ranked row in Individual entries names its row count').toBeGreaterThan(0);
		await console.sourceRows().first().click();
		await console.waitForListSettled();
		expect(await console.totalCardValue(), 'The drilled writer\'s list totals exactly what its card counted').toBe(rankedCount);
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

	test('V109: The list pages with a position line, and Next loads the second page', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');

		expect(await console.getRowCount(), `First load should fill exactly one page of ${PAGE_SIZE} rows`).toBe(PAGE_SIZE);
		expect(await console.positionLine().innerText(), 'The position line should name the first page').toMatch(/^Rows 1 to 50 of [\d,]+$/);
		const firstPageTexts = await console.getRowTexts();

		await console.clickNextPage();

		expect(await console.getRowCount(), 'The second page replaces the first, it is not appended').toBe(PAGE_SIZE);
		expect(await console.positionLine().innerText(), 'The position line should name the second page').toMatch(/^Rows 51 to 100 of [\d,]+$/);
		expect(await console.getRowTexts(), 'The second page holds other rows').not.toEqual(firstPageTexts);
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

			// The index has caught up, so a term that finds nothing now finds nothing because of how it is read. The
			// search reads a star and the word AND as plain text: a star does not stand for the rest of a word, and
			// AND does not join two words found apart. No entry holds either text, so both searches list nothing.
			for(const literalTerm of [WILDCARD_SEARCH_TERM, OPERATOR_SEARCH_TERM])
			{
				await console.search('');
				await console.search(literalTerm);
				expect(await console.getRowCount(), `Expected no entries for "${literalTerm}": the search reads it as plain text`).toBe(0);
				await expect(console.emptyState(), `Expected the empty state for "${literalTerm}"`).toBeVisible();
			}

			// The other side of the same rule: an entry whose message holds a star or the word AND as text is found
			// by that text, and it is the only entry listed. The bulk seed writes it in the same insert as the token's
			// entry, so the index holds both; the search is still repeated for a short while in case it lags.
			for(const literalTerm of [LITERAL_STAR_SEARCH_TERM, LITERAL_AND_SEARCH_TERM])
			{
				await expect.poll(async() =>
				{
					await console.search('');
					await console.search(literalTerm);
					return console.getRowTexts();
				}, {message: `Expected only the "${LITERAL_ENTRY_MESSAGE}" entry for "${literalTerm}"`, timeout: LITERAL_SEARCH_WAIT_MILLISECONDS})
				.toEqual([expect.stringContaining(LITERAL_ENTRY_MESSAGE)]);
			}

			// A body search keeps the writer filter. Under the token's own search, the ranked sources include the
			// seeded row's writer; pinning it and searching again lists exactly the entries the records hold.
			await console.search('');
			await console.search(BODY_SEARCH_TOKEN);
			const tokenSource = console.root().locator(`[data-testid="source-row"][data-source="${BODY_SEARCH_SOURCE}"]`).first();
			await expect(tokenSource, `Expected ${BODY_SEARCH_SOURCE} among the ranked sources under the token's search`).toBeVisible();
			const tokenOrigin = await tokenSource.getAttribute('data-origin');
			await tokenSource.click();
			await console.waitForListSettled();
			await console.search(BODY_SEARCH_TOKEN);
			await expect(console.sourceFilterPill(), 'Expected the source pill to stay while the body search runs').toBeVisible();
			const expectedUnderSource = countEntriesHoldingToken(BODY_SEARCH_TOKEN, BODY_SEARCH_SOURCE, tokenOrigin);
			expect(expectedUnderSource, `Expected the records to hold the token under ${BODY_SEARCH_SOURCE}`).toBeGreaterThan(0);
			expect(await console.getRowCount(), `Expected the body search under ${BODY_SEARCH_SOURCE} to list the entries the records hold`)
			.toBe(expectedUnderSource);

			// Pinned to a writer whose entries do not hold the token, the same body search lists only what that
			// writer's records hold, so the seeded row from the other writer stays out. The other writer is found
			// under the correlation token's search, because with no search a busy window can hold back the ranking.
			await console.removeSourceFilter();
			await console.search('');
			await console.search(OTHER_WRITER_SEARCH_TERM);
			const otherSource = console.root().locator(`[data-testid="source-row"]:not([data-source="${BODY_SEARCH_SOURCE}"])`).first();
			await expect(otherSource, 'Expected a ranked source other than the token\'s writer').toBeVisible();
			const otherSourceName = await otherSource.getAttribute('data-source');
			const otherOrigin = await otherSource.getAttribute('data-origin');
			await otherSource.click();
			await console.waitForListSettled();
			await console.search(BODY_SEARCH_TOKEN);
			await expect(console.sourceFilterPill(), 'Expected the source pill to stay while the body search runs').toBeVisible();
			const expectedUnderOther = countEntriesHoldingToken(BODY_SEARCH_TOKEN, otherSourceName, otherOrigin);
			expect(await console.getRowCount(), `Expected the body search under ${otherSourceName} to list the entries the records hold`)
			.toBe(expectedUnderOther);
			test.info().annotations.push({
				type: 'notes',
				description: `Body search under ${BODY_SEARCH_SOURCE}: ${expectedUnderSource} entries; under ${otherSourceName}: ${expectedUnderOther}`
			});
			await console.removeSourceFilter();
		}
		else
		{
			const empty = await console.emptyState().isVisible().catch(() => false);
			expect(empty, 'A zero-hit body search should render the empty state, not a broken list').toBeTruthy();
			const note = 'SOSL body-only search returned no rows (search index not yet caught up): verify manually if this persists across the run';
			test.info().annotations.push({type: 'notes', description: note});
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

		// The run and its window live on in the address once the stamp is dropped.
		expect(page.url(), 'The hand-off was rewritten without its stamp').not.toContain('c__viewLogsAt');
		expect(page.url(), 'and carries the run').toContain(`c__correlationId=${CHAIN_CORRELATION}`);
		expect(page.url(), 'and its window').toContain('c__windowStart');
		await page.reload();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.correlationPill(), 'A reload keeps the pill').toBeVisible();
		expect(await console.getRowCount(), 'and the window: the same four hops').toBe(4);
		expect(await console.dateRangeLabel(), 'The range control still shows the custom window').toContain('Custom');
		await page.goBack();
		await waitForPageLoad(page);
		expect(page.url(), 'Back returns to the Chain Monitor').toContain('ChainMonitor');
		await page.goForward();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.correlationPill(), 'Forward returns to the pinned run').toBeVisible();

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

	test('V113: Detail drawer renders payload tabs, resolved user, and an entry no run holds reads as the action\'s own', async({page}) =>
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

		// Chain gating, negative side: the correlated quote validation shares a correlation id but NO run
		// holds it and no root reaches it, which is the definition of an action's own entry, a legacy one
		// recorded before roots were tracked. So the timeline renders, Open in Chain Monitor stays hidden
		// (no run to open), and the drawer offers the whole action instead. The "not a registered async
		// chain" note now belongs only to a correlated entry whose root differs from its correlation while
		// no run holds it, a step whose run record is gone. The drawer's Jest suite proves that one.
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.search(SYNC_CORRELATION);
		expect(await console.getRowCount(), 'All three correlated quote-validation rows should match').toBe(3);
		await console.selectRow(0);
		await console.detailPanel().waitFor({state: 'visible', timeout: 15_000});
		expect(await console.chainButton().isVisible().catch(() => false),
				'A correlation without a registered chain must NOT offer Open in Chain Monitor').toBeFalsy();
		await expect(console.showWholeActionButton(), 'The drawer should offer the whole action instead').toBeVisible();
		await console.openDrawerTab('Timeline');
		await expect(console.timelineGroups(), 'The correlated timeline should render its transaction groups').toBeVisible();
		expect(await console.timelineEntries().count(), 'The timeline should list the correlated hops').toBeGreaterThanOrEqual(3);
		await expect(console.timelineActionNote(), 'The action\'s-own note should render').toBeVisible();
		expect(await console.timelineActionNote().innerText(), 'The note should say the action wrote the entry itself')
		.toContain('written by the action itself');
	});

	test('V122: A page past two thousand rows loads through the cursor engine without an OFFSET failure', async({page}) =>
	{
		test.setTimeout(600_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.selectDateRange('Last 30 days');
		await console.selectPageSize(100);

		// SOQL OFFSET caps at 2,000 rows; the pager is cursor-based and must reach page 21 and beyond. The bulk seed plus
		// the org's ambient entries guarantee more than 2,000 matches on the widest preset with every level on. Past seven
		// pages there are no page numbers, so the walk is Next, twenty-one times, with a stall guard.
		expect(await console.pageNumberButtons().count(), 'A large set offers no page numbers').toBe(0);
		let position = await console.positionLine().innerText();
		for(let attempt = 0; attempt < 21; attempt++)
		{
			await console.clickNextPage();
			const next = await console.positionLine().innerText();
			expect(next, 'Each Next should move the position line').not.toBe(position);
			position = next;
		}
		test.info().annotations.push({type: 'notes', description: `Position after twenty-one pages of 100: ${position}`});
		expect(position, 'The position line should be past row 2,000').toMatch(/^Rows 2,101 to /);
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
		const spanBefore = `${ascendingBefore.first?.toISOString()}..${ascendingBefore.last?.toISOString()}`;
		const spanAfter = `${ascendingAfter.first?.toISOString()}..${ascendingAfter.last?.toISOString()}`;
		test.info().annotations.push({type: 'notes', description: `Ascending held across DEBUG-off: before ${spanBefore}, after ${spanAfter}`});
	});

	test('V124: Phone width keeps the ribbon scrollable and opens the detail drawer', async({page}) =>
	{
		test.setTimeout(240_000);
		await page.setViewportSize({width: 390, height: 844});
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');

		// The summary ribbon must overflow-scroll at phone width — wrapped or clipped cards were
		// the mobile defect this guards against.
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
		// The pill names the source the way the column does: the writer's own name, never the namespace
		// the writer happens to live under and never a bridge path. The namespace leg only runs where
		// there is a namespace to find: on the unmanaged org the prefix is empty and every string starts
		// with it.
		const prefix = namespacePrefix();
		if(prefix.length > 0)
		{
			expect(pinnedSource.startsWith(prefix), 'The pill names the source as the column does, not the namespace it lives under').toBeFalsy();
		}
		expect(pinnedSource, 'The pill names the source as the column does, with no bridge path in it').not.toContain('/');
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

	test('V142: Origin is stamped by the engine, filters the list, and never shows a bare namespace', async({page}) =>
	{
		test.setTimeout(180_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.waitForListSettled();

		// The card names writers, never the namespace or a bridge prefix.
		const names = await console.sourceRows().locator('.sname').allTextContents();
		for(const name of names)
		{
			expect(name.trim(), 'A ranked source is a writer, not a namespace').not.toBe(namespacePrefix().replace('__', ''));
			expect(name.trim(), 'A ranked source is a writer, not a bridge prefix').not.toMatch(/^(LWC|Flow)$/);
		}

		// The Origin filter narrows the list on its own. FLOW is the sharp probe: the seed writes three Flow rows
		// inside the default window against thousands of Apex rows, so a dead filter cannot pass this.
		const before = await console.getRowCount();
		await console.selectOrigin('FLOW');
		await console.waitForListSettled();
		const rowsAfter = await console.getRowCount();
		expect(rowsAfter, 'The Origin filter drops every row another origin wrote').toBeLessThan(before);
		expect(rowsAfter, 'The Flow rows the seed wrote stay in the list').toBeGreaterThan(0);
		expect(await console.originFilterValue(), 'The Origin filter holds the origin that was chosen').toBe('FLOW');
		const origins = await console.sourceRows().evaluateAll((rows) => rows.map((row) => row.dataset.origin));
		expect(origins.length, 'The card still ranks a writer while the filter is on').toBeGreaterThan(0);
		expect(origins.every((origin) => origin === 'FLOW'), 'Under an Origin filter the card ranks only that origin').toBeTruthy();

		// Org truth for the Framework branch: in a managed install every line a framework class wrote is FRAMEWORK.
		// A no-namespace org has no framework prefix to match against, so the check only runs when namespaced.
		const prefix = namespacePrefix();
		if(prefix.length > 0)
		{
			// The write-log action's own default label is namespaced but written under a Flow context, so it is
			// stamped FLOW by design: exclude that one bridge label rather than every class-method with a slash.
			const dottedPrefix = prefix.replace('__', '.');
			const frameworkRows = soqlQuery(`SELECT ${prefix}Origin__c FROM ${prefix}LogEntry__c`
					+ ` WHERE ${prefix}ClassMethod__c LIKE '${dottedPrefix}%' AND ${prefix}Origin__c != null`
					+ ` AND (NOT ${prefix}ClassMethod__c LIKE '${dottedPrefix}FLOW_WriteLog/%') LIMIT 200`);
			test.info().annotations.push({type: 'notes', description: `Framework-written rows checked: ${frameworkRows.length}`});
			expect(frameworkRows.length, 'A managed install has framework-written rows to check').toBeGreaterThan(0);
			expect(frameworkRows.every((row) => row[`${prefix}Origin__c`] === 'FRAMEWORK'), 'Every framework-written line stamps FRAMEWORK').toBeTruthy();
		}
		else
		{
			test.info().annotations.push({type: 'notes', description: 'Framework-origin check skipped: unmanaged org has no namespace prefix to match.'});
		}
	});

	test('V143: The Source column names each writer with its origin, a Flow and a component too, and sorts by the writer', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		const labels = readShippedLabelValues();
		await openEntriesListOnTheWidestWindow(console);

		const cellCount = await console.sourceCells().count();
		expect(cellCount, 'Every listed row renders a Source cell').toBeGreaterThan(0);

		// The seed's Flow line and component line are logged under a bridge class (`Flow/Order Intake`,
		// `LWC/orderPanel.submitOrder`), so a column that reads the class shows `Flow.1` and loses the
		// component's name; a column that reads the writer names both. Each is reached by its own
		// message: both were back-dated, so neither is on page one of the unfiltered list.
		const flowSearch = {term: FLOW_SEARCH_TERM, writer: FLOW_WRITER, originName: labels.LogConsole_OriginFlow,
			rowMessage: 'The Flow line is on the page once the list is narrowed to its own message',
			writerMessage: 'Under the Flow line\'s own message every Source cell names the Flow that wrote it',
			pillMessage: 'Every line the Flow wrote carries an origin beside its writer',
			originMessage: 'The Flow line names the Flow origin beside its writer'};
		const componentSearch = {term: COMPONENT_SEARCH_TERM, writer: COMPONENT_WRITER, originName: labels.LogConsole_OriginComponent,
			rowMessage: 'The component line is on the page once the list is narrowed to its own message',
			writerMessage: 'Under the component line\'s own message every Source cell names the component and its method',
			pillMessage: 'Every line the component wrote carries an origin beside its writer',
			originMessage: 'The component line names the Component origin beside its writer'};
		await assertSearchedWriterNamesEveryCell(console, page, flowSearch);
		await assertSearchedWriterNamesEveryCell(console, page, componentSearch);
		await console.search('');

		// Back on the whole list: an Apex writer names the origin the engine stamped, in the package's
		// own words, and no cell that carries a pill reads as a bridge path or as the bare namespace the
		// framework's own classes live under. A cell with no pill is an entry written before entries
		// stored their writer and still reads as its class.
		const originTexts = (await console.sourceOriginPills().allInnerTexts()).map((text) => text.trim());
		expect(originTexts, 'An Apex writer names the Apex origin').toContain(labels.LogConsole_OriginApex);
		await assertEveryNamedSourceNamesItsWriter(console, page);

		const sorted = await assertSourceColumnSortsByWriter(console);
		test.info().annotations.push({type: 'notes',
			description: `Writers ascending: ${sorted.ascending.join(', ')} | descending: ${sorted.descending.join(', ')}`});
	});

	test('V144: The drawer\'s timeline shows icons where it showed glyphs, and every copy button says what it copies', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		const labels = readShippedLabelValues();
		await openTimelineForTimedOutHop(console);
		await assertTimelineShowsNoGlyphs(console);
		await assertTimelineMarksAreIcons(console, labels);
		await assertTimelineHoldsItsShape(console, WIDE_VIEWPORT_WIDTH);
		await assertTimelineHoldsItsShapeWhenNarrowed(console, page);
		await assertChevronTurnsWithItsTransaction(console, page);
		await assertEveryCopyButtonSaysWhatItCopies(console, labels);
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

	test('V126: A chain deep link with no window end moves the end on Refresh while the chain may still run', async({page}) =>
	{
		test.setTimeout(300_000);
		const console = new LogConsolePage(page);
		const windowStart = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();

		// A link to one chain run whose source was still running carries no upper bound. The console
		// ends the range at the moment the link opened, and the end follows the run: each Refresh moves
		// it to now, so entries the run writes afterwards stay inside the window. This is the run-link
		// path (the chain key and a window start, no hand-off stamp); V154 proves the action path.
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
		const arrivalEnd = await readRangeEnd(console);
		expect(arrivalEnd, 'The To inputs should be seeded from the link-arrival instant').toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/);
		expect(await console.getRowCount(), 'The chain hops should be inside the pinned window').toBeGreaterThan(0);

		await console.page.waitForTimeout(FOLLOWING_READING_GAP_MILLISECONDS);
		await console.root().locator('[data-spec-id="refresh-action"]').first().click();
		await console.waitForListSettled();
		const refreshedEnd = await readRangeEnd(console);
		expect(refreshedEnd > arrivalEnd, `Refresh should move the end of a range that follows the run past ${arrivalEnd}, read ${refreshedEnd}`).toBeTruthy();
		await expect(console.correlationPill(), 'Refresh keeps the run pinned').toBeVisible();
		test.info().annotations.push({type: 'notes', description: `Window end followed the run across Refresh: ${arrivalEnd} to ${refreshedEnd}`});
	});

	test('V154: A link into a still-running action moves the window end on Refresh, then settles on the real end', async({page}) =>
	{
		test.setTimeout(300_000);
		const console = new LogConsolePage(page);
		const timeZone = test.info().project.use.timezoneId;
		const rangeEnd = () => readRangeEnd(console);
		const refresh = async() =>
		{
			await console.root().locator('[data-spec-id="refresh-action"]').first().click();
			await console.waitForListSettled();
		};

		executeAnonymousApex(startFollowingActionApex());
		try
		{
			// The hand-off the Chain Monitor sends for a whole action. The action has not ended, so the range ends at the
			// moment the link opened, and that end follows the action for as long as the reader leaves the range alone.
			await console.page.goto(`${getInstanceUrl()}/lightning/n/${console.tabApiName()}?c__rootCorrelationId=${ACTION_FOLLOWING}&c__viewLogsAt=${Date.now()}`,
					{waitUntil: 'domcontentloaded'});
			await waitForPageLoad(console.page);
			await console.root().waitFor({state: 'visible', timeout: 60_000});
			await console.waitForListSettled();
			await expect(console.actionPill(), 'The link should pin the action').toBeVisible();
			await expect(console.rangeNote(), 'The range should be the action\'s lifetime').toHaveText('Date range set to this action\'s lifetime.');
			const arrivalEnd = await rangeEnd();

			await console.page.waitForTimeout(FOLLOWING_READING_GAP_MILLISECONDS);
			await refresh();
			const refreshedEnd = await rangeEnd();
			expect(refreshedEnd > arrivalEnd, `Refresh should move the end of a running action's range past ${arrivalEnd}, read ${refreshedEnd}`).toBeTruthy();

			// The action ends: its last entry is written and its run completes. The next Refresh reads it as ended and the
			// range stops following, settling on the last entry plus the console's margin.
			executeAnonymousApex(endFollowingActionApex());
			const lastEntry = soqlQuery(`SELECT CreatedDate FROM ${namespacePrefix()}LogEntry__c WHERE ${namespacePrefix()}RootCorrelationId__c = '${ACTION_FOLLOWING}'`
					+ ' ORDER BY CreatedDate DESC LIMIT 1')[0];
			const settledEnd = toRangeInputText(new Date(new Date(lastEntry.CreatedDate.replace(/\+0000$/, 'Z')).getTime() + ACTION_RANGE_MARGIN_MILLISECONDS), timeZone);
			await refresh();
			expect(await rangeEnd(), 'Once the action has ended, Refresh should settle the end on its last entry plus the margin').toBe(settledEnd);

			await console.page.waitForTimeout(FOLLOWING_READING_GAP_MILLISECONDS);
			await refresh();
			expect(await rangeEnd(), 'A settled range stays where it settled').toBe(settledEnd);
			test.info().annotations.push({type: 'notes', description: `Arrived ${arrivalEnd}, refreshed ${refreshedEnd}, settled ${settledEnd}`});
		}
		finally
		{
			executeAnonymousApex(removeFollowingActionApex());
		}
	});

	test('V132: Show the whole action pins the action, the banner tells its story, a chip narrows, and the monitor round-trips', async({page}) =>
	{
		test.setTimeout(300_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.selectDateRange('Last 24 hours');
		await console.search(ACTION_OWN_MESSAGE);
		expect(await console.getRowCount(), 'The action\'s own entry should be listed').toBeGreaterThan(0);
		await console.selectRow(0);
		await console.detailPanel().waitFor({state: 'visible', timeout: 15_000});

		// The action's own entry: an Action row marked as the action's own, no per-run chain button.
		expect(await console.metaAction().innerText(), 'The Action row carries the action id').toContain(ACTION_CHECKOUT);
		expect(await console.metaAction().innerText(), 'The Action row says the action wrote the entry itself').toContain('this entry was written by the action itself');
		await expect(console.chainButton(), 'No run holds the action\'s own id, so no Open in Chain Monitor').toHaveCount(0);

		await console.showWholeActionButton().click();
		await console.waitForListSettled();

		await expect(console.actionPill(), 'The action pill should be on').toBeVisible();
		await expect(console.rangeNote(), 'The range note should explain the lifetime range').toHaveText('Date range set to this action\'s lifetime.');
		expect(await console.dateRangeLabel(), 'The range control should show the custom range').toContain('Custom');
		expect(await console.levelPressed('ERROR') && await console.levelPressed('WARN') && await console.levelPressed('INFO'), 'ERROR, WARN and INFO should be on').toBeTruthy();
		expect(await console.getRowCount(), 'The action\'s own two entries and its three chains\' entries').toBe(5);
		expect(await console.pageNumberButtons().count(), 'A one-page set shows its page number').toBeGreaterThan(0);
		expect(await console.getColumnHeaderText(), 'Time should sort ascending on arrival').toContain('Sorted Ascending');
		const rowTexts = await console.getRowTexts();
		expect(rowTexts[0], 'The Chain column names the action\'s own entry').toContain('this action');
		expect(rowTexts.join('\n'), 'The Chain column names a chain by name and number').toMatch(/E2E Checkout Reserve · CHAIN-\d+/);

		const sentence = await console.actionBannerSentence().innerText();
		expect(sentence, 'The sentence starts with the date fragment').toContain('This action started on');
		expect(sentence, 'The sentence carries the exact counts').toContain('It ran 3 chains, 1 of them failed.');
		expect(await console.actionChips().count(), 'Three chips for three chains').toBe(3);
		expect(await console.actionChips().nth(0).innerText(), 'The failed chain is the first chip').toContain('E2E Checkout Notify');
		expect(await console.actionChips().nth(2).innerText(), 'The nested chain says who launched it').toMatch(/launched by E2E Checkout Reserve · CHAIN-\d+/);
		await expect(console.actionMoreChains(), 'Nothing beyond the chips').toHaveCount(0);

		// A search inside the action.
		await console.search('Ledger');
		expect(await console.getRowCount(), 'The search applies inside the action').toBe(1);
		await expect(console.actionPill(), 'The pill survives a search').toBeVisible();
		await console.search('');

		// A chip narrows to one chain, worded as the chain pill.
		await console.actionChips().nth(0).click();
		await console.waitForListSettled();
		expect(await console.correlationPill().innerText(), 'The chip pins the chain by name and number').toMatch(/Chain: E2E Checkout Notify · CHAIN-\d+/);
		expect(await console.getRowCount(), 'One chain\'s one entry').toBe(1);

		// The pin and the narrowing are in the address, so Back undoes one step at a time and a refresh keeps them.
		expect(page.url(), 'The in-place pin wrote the action into the address').toContain(`c__rootCorrelationId=${ACTION_CHECKOUT}`);
		expect(page.url(), 'without a stamp').not.toContain('c__viewLogsAt');
		expect(page.url(), 'The chip wrote the chain into the address').toContain(`c__correlationId=${CHAIN_NOTIFY}`);
		await page.goBack();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.correlationPill(), 'Back undoes the chip').toHaveCount(0);
		await expect(console.actionPill(), 'and keeps the action').toBeVisible();
		expect(await console.getRowCount(), 'The whole action is back').toBe(5);
		await page.goBack();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.actionPill(), 'Back again undoes the pin').toHaveCount(0);
		expect(page.url(), 'and the address carries no key').not.toContain('c__rootCorrelationId');
		await page.goForward();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.actionPill(), 'Forward re-pins the action').toBeVisible();
		await page.goForward();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		expect(await console.correlationPill().innerText(), 'Forward again re-narrows to the chip, named').toMatch(/Chain: E2E Checkout Notify · CHAIN-\d+/);
		await page.reload();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.actionPill(), 'A reload keeps the action').toBeVisible();
		expect(await console.correlationPill().innerText(), 'and the chip, named').toMatch(/Chain: E2E Checkout Notify · CHAIN-\d+/);
		expect(await console.getRowCount(), 'One chain\'s one entry').toBe(1);
		await console.removeCorrelation();
		expect(await console.getRowCount(), 'Removing the chain pill returns to the whole action').toBe(5);
		expect(page.url(), 'and the address keeps the action').toContain(`c__rootCorrelationId=${ACTION_CHECKOUT}`);
		expect(page.url(), 'but not the chain').not.toContain('c__correlationId');

		// To the monitor and back, without a window.
		await console.openChainsButton().click();
		await waitForPageLoad(page);
		expect(page.url(), 'Open the chains lands on the Chain Monitor').toContain('ChainMonitor');
		expect(page.url(), 'The link carries the action').toContain(ACTION_CHECKOUT);
		expect(page.url(), 'The link carries no window').not.toContain('c__windowStart');
		const monitor = new ChainMonitorPage(page);
		await monitor.getActionPill().waitFor({state: 'visible', timeout: 30_000});
		expect(await monitor.getRowCount(), 'The monitor lists the action\'s three runs').toBe(3);
		const launchedUnder = await monitor.getLaunchedUnderValues();
		expect(launchedUnder.filter((value) => value === 'this action'), 'Two runs were launched by the click').toHaveLength(2);
		expect(launchedUnder.some((value) => /E2E Checkout Reserve · CHAIN-\d+/.test(value)), 'The nested run names its launcher').toBeTruthy();

		await monitor.getShowActionLogsButton().click();
		await waitForPageLoad(page);
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		expect(page.url(), 'Show the action\'s logs carries the action').toContain(ACTION_CHECKOUT);
		expect(page.url(), 'and no window keys').not.toContain('c__windowStart');
		await expect(console.actionPill(), 'The console lands on the action').toBeVisible();
		expect(page.url(), 'The hand-off was rewritten without its stamp').not.toContain('c__viewLogsAt');
		expect(page.url(), 'and still carries the action').toContain(`c__rootCorrelationId=${ACTION_CHECKOUT}`);
	});

	test('V133: The drawer\'s Open in Chain Monitor keeps its per-run meaning under an action', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.search(ACTION_CHECKOUT);
		await console.waitForListSettled();
		await expect(console.actionPill(), 'A pasted action id pins the action').toBeVisible();
		expect(await console.searchValue(), 'A recognised id clears the box').toBe('');

		const notifyIndex = await console.findRowIndexByText('Notification gateway refused');
		expect(notifyIndex, 'The failed chain\'s entry should be listed').toBeGreaterThanOrEqual(0);
		await console.selectRow(notifyIndex);
		await console.detailPanel().waitFor({state: 'visible', timeout: 15_000});
		expect(await console.metaCorrelationChain().innerText(), 'The Correlation row names the chain').toMatch(/E2E Checkout Notify · CHAIN-\d+/);
		expect(await console.metaAction().innerText(), 'A run inside a larger action carries no note').not.toContain('started the action');
		await expect(console.showWholeActionButton(), 'The whole action is already pinned, so the button hides').toHaveCount(0);
		await console.chainButton().click();
		await waitForPageLoad(page);
		expect(page.url(), 'Open in Chain Monitor carries the run').toContain(CHAIN_NOTIFY);
		expect(page.url(), 'and never the action').not.toContain('c__rootCorrelationId');
		const monitor = new ChainMonitorPage(page);
		await monitor.getDetailPanel().waitFor({state: 'visible', timeout: 30_000});
		await expect(monitor.getActionPill(), 'The monitor lands unscoped').toHaveCount(0);

		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();
		await console.search(ACTION_NIGHTLY);
		await console.waitForListSettled();
		// Both the origin run and its restart clone carry the job's name, so the origin is the one with the
		// lowest chain number: it started first, and the clone was numbered after it.
		const nightlyRowTexts = await console.getRowTexts();
		let originIndex = -1;
		let lowestChainNumber = Number.MAX_SAFE_INTEGER;
		nightlyRowTexts.forEach((text, index) =>
		{
			const match = text.match(/E2E Nightly Sync · CHAIN-(\d+)/);
			if(match && Number(match[1]) < lowestChainNumber)
			{
				lowestChainNumber = Number(match[1]);
				originIndex = index;
			}
		});
		expect(originIndex, 'The nightly job\'s own entries list under its action').toBeGreaterThanOrEqual(0);
		await console.selectRow(originIndex);
		await console.detailPanel().waitFor({state: 'visible', timeout: 15_000});
		expect(await console.metaAction().innerText(), 'The Action row says the chain started the action').toContain('this chain started the action');
		await expect(console.chainButton(), 'and the run button stays').toBeVisible();
	});

	test('V134: A pasted chain id pins the chain pill and an unknown id searches as text; a legacy action reads its own sentence', async({page}) =>
	{
		test.setTimeout(240_000);
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		await console.enableAllLevels();

		await console.search(CHAIN_NOTIFY);
		expect(await console.correlationPill().innerText(), 'A chain id pins the chain, never an action').toMatch(/Chain: E2E Checkout Notify · CHAIN-\d+/);
		await expect(console.actionPill(), 'No action pill for a chain id').toHaveCount(0);
		expect(page.url(), 'A pasted chain id wrote the chain into the address').toContain(`c__correlationId=${CHAIN_NOTIFY}`);

		// The pin was made in place and nothing has reloaded or gone Back since, so the platform may never have handed
		// that address back to the console. Closing the pill still has to take the key out of the URL, or a refresh
		// would bring back the chain the reader just cleared.
		await console.removeCorrelation();
		expect(page.url(), 'Closing the pill drops the chain from the address with no reload in between').not.toContain('c__correlationId');
		await console.search(CHAIN_NOTIFY);
		expect(await console.correlationPill().innerText(), 'and the chain pins again for the history steps').toMatch(/Chain: E2E Checkout Notify · CHAIN-\d+/);

		await page.reload();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		expect(await console.correlationPill().innerText(), 'A reload keeps the chain pill, named').toMatch(/Chain: E2E Checkout Notify · CHAIN-\d+/);
		await page.goBack();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.correlationPill(), 'Back unpins the chain').toHaveCount(0);
		// The restored history entry may re-mount the console on its default levels, so the journey's
		// original precondition is re-applied before the shipped legacy-action checks continue.
		await console.enableAllLevels();

		await console.search(UNKNOWN_ID);
		expect(await console.searchValue(), 'An unknown id stays in the box as text').toBe(UNKNOWN_ID);
		await expect(console.emptyState(), 'and matches nothing').toBeVisible();
		await console.search('');

		await console.search(ACTION_LEGACY);
		await expect(console.actionPill(), 'A rootless correlation pins as a legacy action').toBeVisible();
		expect(await console.actionBannerSentence().innerText(), 'The legacy sentence').toBe('This action was recorded before chains were tracked by action.');
		expect(await console.actionChips().count(), 'The chain that adopted the id is the one chip').toBe(1);
		await expect(console.openChainsButton(), 'No monitor button for a legacy action').toHaveCount(0);
		await console.selectRow(0);
		await console.detailPanel().waitFor({state: 'visible', timeout: 15_000});
		expect(await console.metaAction().innerText(), 'The Action row says the entry predates action tracking').toContain('recorded before chains were tracked by action');

		// A run pasted while another action is pinned belongs to no part of that action's story: the nightly restart
		// under the checkout action. The paste pins the run alone rather than claiming a narrowing that does not
		// exist, which would leave the reader an empty list under the wrong action's banner.
		await console.search(ACTION_CHECKOUT);
		await expect(console.actionPill(), 'The checkout action is pinned before the paste').toBeVisible();
		await console.search(CHAIN_NIGHTLY_RESTART);
		await expect(console.actionPill(), 'A pasted run drops the action that was pinned').toHaveCount(0);
		await expect(console.actionBannerSentence(), 'and its banner with it').toHaveCount(0);
		expect(await console.correlationPill().innerText(), 'leaving the run as the chain pill, named').toMatch(/Chain: E2E Nightly Sync · CHAIN-\d+/);
		expect(page.url(), 'The address records the run').toContain(`c__correlationId=${CHAIN_NIGHTLY_RESTART}`);
		expect(page.url(), 'and no longer the action').not.toContain('c__rootCorrelationId');
		expect(await console.rows().count(), 'The run\'s own entries are listed, never an empty list').toBeGreaterThan(0);

		await page.goBack();
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.actionPill(), 'One Back puts the action back').toBeVisible();
		await expect(console.correlationPill(), 'with no chain narrowing it').toHaveCount(0);
	});

	test('V135: With the drawer open at 1024 the list keeps four columns, and at 820 the drawer offers the way back', async({page}) =>
	{
		test.setTimeout(240_000);
		await page.setViewportSize({width: 1024, height: 800});
		const console = new LogConsolePage(page);
		await console.navigate();
		await console.switchView('entries');
		expect(await console.getColumnHeaderText(), 'Without the drawer every column shows').toContain('Source');
		await console.selectRow(0);
		await expect(console.detailPanel()).toBeVisible();
		const compactHeaders = await console.getColumnHeaderText();
		expect(compactHeaders, 'The compact set keeps Time').toContain('Time');
		expect(compactHeaders, 'and Chain').toContain('Chain');
		expect(compactHeaders, 'and drops Source').not.toContain('Source');
		expect(compactHeaders, 'and drops the log number').not.toContain('Log Number');
		const ribbon = console.root().locator('.summary').first();
		expect(await ribbon.evaluate((element) => window.getComputedStyle(element).overflowX), 'The ribbon scrolls sideways at 1024').toBe('auto');

		// The console keeps a selection across a view switch when the opened entry is also listed as a problem, so
		// the drawer is closed by hand here: the next check is about the problems list without it.
		await console.closeDetail();
		await console.switchView('problems');
		await console.waitForListSettled();
		expect(await console.getColumnHeaderText(), 'Problems without the drawer shows every column').toContain('Source');
		await console.selectRow(0);
		await expect(console.detailPanel(), 'A problem row opens the drawer').toBeVisible();
		const problemHeaders = await console.getColumnHeaderText();
		expect(problemHeaders, 'Problems with the drawer open keeps Level').toContain('Level');
		expect(problemHeaders, 'and Problem').toContain('Problem');
		expect(problemHeaders, 'and Count').toContain('Count');
		expect(problemHeaders, 'and Last seen').toContain('Last seen');
		expect(problemHeaders, 'and drops Source').not.toContain('Source');
		expect(problemHeaders, 'and drops Context').not.toContain('Context');
		expect(problemHeaders, 'and drops the log number').not.toContain('Log Number');
		await console.switchView('entries');
		await console.waitForListSettled();
		await console.selectRow(0);
		await expect(console.detailPanel(), 'The drawer is open again for the 820 step').toBeVisible();

		await page.setViewportSize({width: 820, height: 800});
		await page.waitForTimeout(1000);
		await expect(console.backToListButton(), 'The overlay drawer offers Back to the list').toBeVisible();
		await console.backToListButton().click();
		await expect(console.detailPanel(), 'Back to the list closes the drawer').toHaveCount(0);
	});

	// V136/V137 read the same shaped fixtures from the Chain Monitor's side. They live here, not in
	// part8, because this file's beforeAll is the one owner of the shaped seed and its afterAll the
	// one teardown: the battery runs the two spec files on separate workers, so a second owner would
	// re-seed and tear down underneath this one.
	test('V136: Scoped to the nightly job, the Launched-under column and the Timing row read the origin and the restart', async({page}) =>
	{
		test.setTimeout(240_000);
		const monitor = new ChainMonitorPage(page);
		const scopedUrl = `${getInstanceUrl()}/lightning/n/${namespacePrefix()}ChainMonitor`
				+ `?c__rootCorrelationId=${ACTION_NIGHTLY}&c__viewLogsAt=${Date.now()}`;
		await page.goto(scopedUrl, {waitUntil: 'domcontentloaded'});
		await page.waitForTimeout(5000);
		await waitForSpinnerGone(page);

		await expect(monitor.getActionPill(), 'The pill shows the action').toBeVisible();
		expect(await monitor.getRowCount(), 'The job and its restart clone').toBe(2);
		const launchedUnder = await monitor.getLaunchedUnderValues();
		expect(launchedUnder, 'The origin and the restart, by start time').toContain('started this action');
		expect(launchedUnder.some((value) => /^restart of E2E Nightly Sync · CHAIN-\d+$/.test(value)), 'The clone names its source').toBeTruthy();

		const cloneIndex = (await monitor.getRowTexts()).findIndex((text) => text.includes('restart of'));
		await monitor.selectRow(cloneIndex);
		expect(await monitor.getLaunchedUnderLink().innerText(), 'The Timing row links the restart to its source').toMatch(/^restart of E2E Nightly Sync · CHAIN-\d+$/);
		await monitor.getLaunchedUnderLink().click();
		await page.waitForTimeout(2000);
		expect(await monitor.getLaunchedUnderRow().innerText(), 'Following the link selects the source, which started the action').toContain('started this action');

		await page.setViewportSize({width: 1280, height: 900});
		await page.waitForTimeout(1000);
		await expect.poll(() => monitor.getColumnLabels(), {message: 'At 1280 the scoped list keeps Chain, Status, Started and Launched under', timeout: 15_000})
		.toEqual(['Chain Name', 'Status', 'Started', 'Launched under']);
		await page.setViewportSize({width: 1440, height: 900});
		await page.waitForTimeout(1000);
		await expect.poll(() => monitor.getColumnLabels(), {message: 'Above 1280 the six return', timeout: 15_000}).toHaveLength(6);

		await monitor.getActionPill().locator('button').first().click();
		await page.waitForTimeout(2000);
		await waitForSpinnerGone(page);
		expect(await monitor.getColumnHeaders(), 'Removing the pill drops the column').not.toContain('Launched under');
		await page.setViewportSize({width: 1280, height: 900});
		await page.waitForTimeout(1000);
		await expect.poll(() => monitor.getColumnLabels(), {message: 'Unscoped at 1280 the list keeps three', timeout: 15_000}).toHaveLength(3);
	});

	test('V137: The detail\'s Show the action\'s logs opens the console on the whole action with no window', async({page}) =>
	{
		test.setTimeout(240_000);
		const monitor = new ChainMonitorPage(page);
		await monitor.navigate();
		await monitor.selectRowByChainName('E2E Checkout Ledger');
		expect(await monitor.getLaunchedUnderLink().innerText(), 'The nested run names its launcher').toMatch(/^E2E Checkout Reserve · CHAIN-\d+$/);
		expect(await monitor.getLaunchedUnderRow().locator('..').innerText(), 'with the step note').toContain('a step of that chain launched this one');

		await monitor.getDetailShowActionLogsButton().click();
		await waitForPageLoad(page);
		expect(page.url(), 'The link carries the action').toContain(ACTION_CHECKOUT);
		expect(page.url(), 'and no window keys').not.toContain('c__windowStart');
		expect(page.url(), 'and no run').not.toContain('c__correlationId');

		const console = new LogConsolePage(page);
		await console.root().waitFor({state: 'visible', timeout: 60_000});
		await console.waitForListSettled();
		await expect(console.actionPill(), 'The console lands on the action').toBeVisible();
		expect(page.url(), 'The hand-off was rewritten without its stamp').not.toContain('c__viewLogsAt');
		await page.goBack();
		await waitForPageLoad(page);
		expect(page.url(), 'Back returns to the Chain Monitor').toContain('ChainMonitor');
		await expect(monitor.getDetailPanel(), 'with its detail panel').toBeVisible();
	});
});
