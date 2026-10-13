// SPDX-License-Identifier: BUSL-1.1
const {getInstanceUrl, ensureAuthenticated} = require('../helpers/sf-auth');
const {soqlQuery} = require('../helpers/sf-cli');
const {clickNavTab, waitForPageLoad} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {SPINNER} = require('../helpers/sf-selectors');
const {readColumnLabels} = require('../lib/datatable-headers');
const {ELEMENT_WAIT_MILLISECONDS} = require('../helpers/wait-times');

// How long a drawer may take to appear after its row is selected before the selection counts as failed.
const DETAIL_OPEN_TIMEOUT_MILLISECONDS = 30_000;

// Resolved once per process: 'kern__' on a subscriber org, '' on the no-namespace unmanaged org.
// The Log Console is not a nav tab in the Kern app, so it is reached by tab URL
// (`/lightning/n/<ns>LogConsole`); every other selector is data-testid / class based and therefore
// namespace-stable except the LWC tag names, which get a `c-* , kern-*` alternation (the part8
// chain-step-timeline pattern) so the same page object drives both orgs.
let cachedNamespacePrefix;

// The container renders `c-log-console-table` (a lightning-datatable subtype) in the unmanaged org
// and `kern-log-console-table` under the managed namespace.
const TABLE_TAGS = 'c-log-console-table, kern-log-console-table';

class LogConsolePage
{
	constructor(page)
	{
		this.page = page;
	}

	/**
	 * @description Resolves the org's namespace prefix for the console tab API name by reading the
	 *              CTRL_LogConsole class's NamespacePrefix via the Tooling API. Returns `kern__`
	 *              on a subscriber org and an empty string on the no-namespace unmanaged org.
	 *              Cached for the process so the lookup runs at most once per test run.
	 *
	 * @return {string} The namespace prefix including the trailing `__`, or `''` when unmanaged.
	 */
	namespacePrefix()
	{
		if(cachedNamespacePrefix === undefined)
		{
			const rows = soqlQuery('SELECT NamespacePrefix FROM ApexClass WHERE Name = \'CTRL_LogConsole\' LIMIT 1', {tooling: true});
			const namespace = rows[0] && rows[0].NamespacePrefix;
			cachedNamespacePrefix = namespace ? `${namespace}__` : '';
		}
		return cachedNamespacePrefix;
	}

	tabApiName()
	{
		return `${this.namespacePrefix()}LogConsole`;
	}

	/**
	 * @description Navigates to the Log Console tab by URL (namespace-resolved) and waits for the
	 *              console shell plus the initial list load to settle.
	 */
	async navigate()
	{
		await ensureAuthenticated(this.page);
		await this.page.goto(`${getInstanceUrl()}/lightning/n/${this.tabApiName()}`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(this.page);
		await this.root().waitFor({state: 'visible', timeout: 60_000});
		await this.waitForListSettled();
	}

	/**
	 * @description Navigates to the Log Console tab and returns as soon as its list has rendered, with no
	 *              fixed wait: the open a timer measures. The caller settles afterwards.
	 */
	async navigateUntilRendered()
	{
		await ensureAuthenticated(this.page);
		await this.page.goto(`${getInstanceUrl()}/lightning/n/${this.tabApiName()}`, {waitUntil: 'domcontentloaded'});
		await this.waitForListRendered();
	}

	/**
	 * @description Waits until the list shows a row or its empty state and no spinner is on screen, without
	 *              the fixed settle: what a timed open measures to.
	 */
	async waitForListRendered()
	{
		await this.root().waitFor({state: 'visible', timeout: 60_000});
		await this.rows().first().or(this.emptyState()).waitFor({state: 'visible', timeout: 60_000});
		await this.page.locator(SPINNER).first().waitFor({state: 'hidden', timeout: ELEMENT_WAIT_MILLISECONDS});
	}

	root()
	{
		return this.page.locator('.log-console').first();
	}

	/**
	 * @description Waits for the list spinner to clear plus a short settle so a reload triggered by
	 *              a filter change has replaced the rows before the caller reads them.
	 */
	async waitForListSettled()
	{
		await this.page.waitForTimeout(1500);
		await waitForSpinnerGone(this.page);
		await this.page.waitForTimeout(500);
	}

	// ── view toggle ──────────────────────────────────────────────────────

	viewToggle(view)
	{
		return this.root().locator(`lightning-button[data-view="${view}"]`).first();
	}

	async isViewActive(view)
	{
		// The active view renders as the brand-variant button; lightning-button reflects the
		// variant onto the inner button's slds-button_brand class.
		return this.viewToggle(view).locator('button.slds-button_brand').isVisible().catch(() => false);
	}

	async switchView(view)
	{
		await this.viewToggle(view).click();
		await this.waitForListSettled();
	}

	// ── level (severity) segmented control ───────────────────────────────

	levelToggle(level)
	{
		return this.root().locator(`button.level-seg-btn[data-level="${level}"]`).first();
	}

	async levelPressed(level)
	{
		return (await this.levelToggle(level).getAttribute('aria-pressed')) === 'true';
	}

	async setLevel(level, pressed)
	{
		if(await this.levelPressed(level) !== pressed)
		{
			await this.levelToggle(level).click();
			await this.waitForListSettled();
		}
	}

	async enableAllLevels()
	{
		for(const level of ['ERROR', 'WARN', 'INFO', 'DEBUG'])
		{
			await this.setLevel(level, true);
		}
	}

	// ── ribbon summary cards ──────────────────────────────────────────────

	summaryCards()
	{
		return this.root().locator('[data-testid="summary-card"]');
	}

	levelCard(level)
	{
		return this.root().locator(`[data-testid="summary-card"][data-level="${level}"]`).first();
	}

	sourceRows()
	{
		return this.root().locator('[data-testid="source-row"]');
	}

	originFilter()
	{
		return this.root().locator('[data-spec-id="origin-filter"]');
	}

	async originFilterValue()
	{
		return this.originFilter().evaluate((combobox) => combobox.value ?? '');
	}

	async selectOrigin(value)
	{
		await this.originFilter().evaluate((combobox, chosen) =>
		{
			combobox.value = chosen;
			combobox.dispatchEvent(new CustomEvent('change', {detail: {value: chosen}}));
		}, value);
	}

	approximateBadge()
	{
		return this.root().locator('[data-testid="totals-approximate"]').first();
	}

	/**
	 * @description The number on the ribbon's total card, with the thousands separators stripped, so a
	 *              test can compare it against a ranked source row's own count.
	 */
	async totalCardValue()
	{
		const text = await this.root().locator('[data-spec-id="summary-total-card"] .val').first().innerText();
		return Number(text.replace(/\D/g, ''));
	}

	// ── date range ────────────────────────────────────────────────────────

	async selectDateRange(optionLabel)
	{
		const combobox = this.root().locator('.date-range-combobox').first();
		await combobox.locator('input, button').first().click();
		await this.page.waitForTimeout(500);
		await this.page.getByRole('option', {name: optionLabel, exact: true}).first().click();
		await this.waitForListSettled();
	}

	/**
	 * @description Fills the four custom-range inputs. Accepts dates as `yyyy-mm-dd` and times as
	 *              24-hour `HH:MM`, then converts both to the display formats the org user's en_US
	 *              locale expects (`M/d/yyyy` and `h:mm a`). Lightning date/time inputs validate
	 *              TYPED text against the user locale and reject ISO dates and 24-hour times in
	 *              en_US — the range then never applies and the list silently stays on the prior
	 *              preset (caught 2026-07-03 on V108). Each fill commits with Tab so the input's
	 *              change handler fires before the next field, and the console reloads once all
	 *              four are present and forward-ordered.
	 */
	async setCustomRange({fromDate, fromTime, toDate, toTime})
	{
		const toUsDate = (isoDate) =>
		{
			const [year, month, day] = isoDate.split('-').map(Number);
			return `${month}/${day}/${year}`;
		};
		const toUsTime = (hhmm) =>
		{
			const [hour, minute] = hhmm.split(':').map(Number);
			const meridiem = hour < 12 ? 'AM' : 'PM';
			const hour12 = hour % 12 === 0 ? 12 : hour % 12;
			return `${hour12}:${String(minute).padStart(2, '0')} ${meridiem}`;
		};
		const fill = async(field, value) =>
		{
			const input = this.root().locator(`.customrange-field[data-field="${field}"] input`).first();
			await input.waitFor({state: 'visible', timeout: 10_000});
			await input.fill(value);
			await input.press('Tab');
		};
		await fill('fromDate', toUsDate(fromDate));
		await fill('fromTime', toUsTime(fromTime));
		await fill('toDate', toUsDate(toDate));
		await fill('toTime', toUsTime(toTime));
		await this.waitForListSettled();
	}

	// ── search + filters ─────────────────────────────────────────────────

	searchInput()
	{
		return this.root().locator('.filter-search input').first();
	}

	/**
	 * @description Types a search term and waits past the 300ms debounce plus the reload.
	 */
	async search(term)
	{
		await this.searchInput().fill(term);
		await this.page.waitForTimeout(800);
		await this.waitForListSettled();
	}

	async searchValue()
	{
		return this.searchInput().inputValue();
	}

	correlationPill()
	{
		return this.root().locator('[data-testid="correlation-pill"]').first();
	}

	sourceFilterPill()
	{
		return this.root().locator('[data-testid="source-filter-pill"]').first();
	}

	customRangeError()
	{
		return this.root().locator('[data-testid="custom-range-error"]').first();
	}

	occurrencesReconciliation()
	{
		return this.root().locator('[data-testid="occurrences-reconciliation"]').first();
	}

	/**
	 * @description Removes the pinned correlation by clicking the pill's own remove button, the way a
	 *              reader drops a deep-linked filter. Tolerant about which mark lightning-pill renders
	 *              the button with, since that is base-component internals.
	 */
	async removeCorrelation()
	{
		await this.correlationPill().locator('button.slds-pill__remove, button[title="Remove"], button').first().click();
		await this.waitForListSettled();
	}

	/**
	 * @description Removes the pinned source the occurrences drill left behind, the same way
	 *              `removeCorrelation` drops a deep-linked filter.
	 */
	async removeSourceFilter()
	{
		await this.sourceFilterPill().locator('button.slds-pill__remove, button[title="Remove"], button').first().click();
		await this.waitForListSettled();
	}

	// ── the whole action ─────────────────────────────────────────────────

	actionPill()
	{
		return this.root().locator('[data-testid="action-pill"]').first();
	}

	async removeAction()
	{
		await this.actionPill().locator('button.slds-pill__remove, button[title="Remove"], button').first().click();
		await this.waitForListSettled();
	}

	rangeNote()
	{
		return this.root().locator('[data-testid="action-range-note"]').first();
	}

	actionBannerSentence()
	{
		return this.root().locator('[data-testid="action-banner-sentence"]').first();
	}

	actionChips()
	{
		return this.root().locator('[data-testid="action-chain-chip"]');
	}

	actionMoreChains()
	{
		return this.root().locator('[data-testid="action-more-chains"]').first();
	}

	openChainsButton()
	{
		return this.root().locator('[data-testid="action-open-chains"]').first();
	}

	// ── pages ────────────────────────────────────────────────────────────

	positionLine()
	{
		return this.root().locator('[data-testid="entries-position"]').first();
	}

	pageNumberButtons()
	{
		return this.root().locator('[data-testid="pager-page"]');
	}

	/**
	 * @description The pager's Next, whose rendered inner button carries the disabled state.
	 * @returns {Object} The button's locator.
	 */
	getNextPageButton()
	{
		return this.root().locator('[data-testid="pager-next"]').first().locator('button');
	}

	/**
	 * @description Every row's key (the entry's record id for a plain row), in the order the list shows them.
	 * @returns {Promise<Array<string>>} The keys.
	 */
	async getRowKeys()
	{
		return this.rows().evaluateAll((rows) => rows.map((row) => row.getAttribute('data-row-key-value')));
	}

	async clickNextPage()
	{
		await this.root().locator('[data-testid="pager-next"]').first().click();
		await this.waitForListSettled();
	}

	/**
	 * @description Picks a page size from the pager's combobox. The option's visible text is the
	 *              shipped `LogConsole_PerPage` label filled with the size, so a size of 25 reads
	 *              `25 per page`.
	 */
	async selectPageSize(size)
	{
		const combobox = this.root().locator('[data-testid="pager-size"]').first();
		await combobox.locator('input, button').first().click();
		await this.page.waitForTimeout(500);
		await this.page.getByRole('option', {name: `${size} per page`, exact: true}).first().click();
		await this.waitForListSettled();
	}

	backToListButton()
	{
		return this.root().locator('[data-testid="back-to-list"]').first();
	}

	/**
	 * @description Reads the date-range combobox's displayed value — the preset's own label, e.g.
	 *              `Last 24 hours` or `Custom range…`, which is what the reader sees. lightning-combobox
	 *              renders its trigger as a button in some releases and an input in others, so the value is
	 *              taken from whichever of the two this org painted.
	 *
	 * @return {Promise<string>} The selected preset's label text.
	 */
	async dateRangeLabel()
	{
		const trigger = this.root().locator('.date-range-combobox [role="combobox"], .date-range-combobox input').first();
		const shown = await trigger.evaluate((element) => (element.value ? element.value : element.innerText));
		return (shown || '').trim();
	}

	/**
	 * @description Returns to the console through the navigation bar's Log Console tab rather than by URL.
	 *              A tab opened by a Chain Monitor hand-off is temporary and keeps the URL it was opened
	 *              with, so this is the route that re-delivers a spent deep link — going by URL would
	 *              silently pass whether or not the hand-off state was ever dropped.
	 */
	async returnByNavigationTab()
	{
		await clickNavTab(this.page, 'Log Console');
		await this.root().waitFor({state: 'visible', timeout: 60_000});
		await this.waitForListSettled();
	}

	async clearAll()
	{
		await this.root().getByRole('button', {name: 'Clear all'}).first().click();
		await this.waitForListSettled();
	}

	// ── list table ────────────────────────────────────────────────────────

	table()
	{
		return this.root().locator(TABLE_TAGS).first();
	}

	rows()
	{
		return this.table().locator('tbody tr');
	}

	async getRowCount()
	{
		return this.rows().count();
	}

	async getRowTexts()
	{
		return this.rows().allInnerTexts();
	}

	async findRowIndexByText(needle)
	{
		const texts = await this.getRowTexts();
		return texts.findIndex((text) => text.includes(needle));
	}

	/**
	 * @description Finds the first row that is a read-time-grouped problem, or -1 when the list holds
	 *              none. Keyed on the Log Number cell's grouped pill rather than on any dash in the
	 *              row text: a tagged problem logged with no source or no execution context carries a
	 *              dash in those cells too, so text matching would pick a row that has a record behind
	 *              it and the grouped-problem assertions would then fail for the wrong reason.
	 */
	async findGroupedRowIndex()
	{
		const rows = this.rows();
		const count = await rows.count();
		for(let index = 0; index < count; index++)
		{
			if(await rows.nth(index).locator('.log-number-grouped').count() > 0)
			{
				return index;
			}
		}
		return -1;
	}

	/**
	 * @description Selects a row via its single-select radio (max-row-selection is 1), falling back
	 *              to a plain row click — the same tolerant pattern as the Chain Monitor page object.
	 */
	async selectRow(index)
	{
		await this.clickRow(index);
		await this.page.waitForTimeout(2000);
		await waitForSpinnerGone(this.page);
	}

	/**
	 * @description Clicks a row's selector (its radio when the table shows one, the row itself otherwise) and
	 *              returns at once, with no settle.
	 * @param {number} index The row's index on the page.
	 */
	async clickRow(index)
	{
		const row = this.rows().nth(index);
		const radio = row.locator('lightning-primitive-cell-checkbox, input[type="radio"]').first();
		if(await radio.isVisible().catch(() => false))
		{
			await radio.click();
		}
		else
		{
			await row.click();
		}
	}

	/**
	 * @description Selects a row and returns as soon as the drawer is on screen, with no fixed wait: the read a
	 *              walk times (selectRow sleeps two seconds and then waits up to two more for a spinner to appear,
	 *              which a timer around it would count). The caller settles afterwards, untimed.
	 * @param {number} index The row's index on the page.
	 */
	async selectRowUntilDetail(index)
	{
		await this.clickRow(index);
		await this.detailPanel().waitFor({state: 'visible', timeout: DETAIL_OPEN_TIMEOUT_MILLISECONDS});
	}

	async clickColumnHeader(columnName)
	{
		const sortButton = this.table().getByRole('button', {name: `Sort by: ${columnName}`}).first();
		await sortButton.scrollIntoViewIfNeeded();
		await sortButton.click({timeout: 30_000});
		await this.waitForListSettled();
	}

	async getColumnHeaderText()
	{
		return this.table().locator('thead').innerText();
	}

	/**
	 * @description The list's data-column labels, in order, so a width check can compare the whole
	 *              column set exactly rather than searching the header text for one word. Read by the
	 *              shared datatable-header reader, which the Chain Monitor page object uses too.
	 *
	 * @return {Promise<string[]>} The column labels, in the order the list shows them.
	 */
	async getColumnLabels()
	{
		return readColumnLabels(this.table());
	}

	emptyState()
	{
		return this.root().locator('[data-testid="empty-state"]').first();
	}

	/**
	 * @description Every Source cell in the list, whole: the writer's text with its origin pill's text
	 *              after it, which is what a reader sees in the column.
	 */
	sourceCells()
	{
		return this.root().locator('[data-spec-id="entries-source-cell"]');
	}

	/**
	 * @description The writer's own mark out of every Source cell that carries an origin pill, read
	 *              without the pill's text beside it. A pill is only drawn where the entry stored a
	 *              writer, so these are the cells that really name one: an entry written before entries
	 *              stored a writer fills the same mark with its class and method and carries no pill,
	 *              and is left out here.
	 */
	sourceCellNames()
	{
		return this.sourceCells().filter({has: this.page.locator('[data-spec-id="entries-source-origin"]')}).locator('.writer-name');
	}

	sourceOriginPills()
	{
		return this.root().locator('[data-spec-id="entries-source-origin"]');
	}

	// ── detail drawer ─────────────────────────────────────────────────────

	detailPanel()
	{
		return this.root().locator('[data-testid="detail-panel"]').first();
	}

	/**
	 * @description Closes the drawer with its own close control and waits until it is gone. The click goes to
	 *              the native button inside the Lightning host, where the click handler listens.
	 */
	async closeDetail()
	{
		await this.detailPanel().locator('[data-testid="close-button"] button').first().click();
		await this.detailPanel().waitFor({state: 'hidden'});
	}

	levelBadge()
	{
		return this.detailPanel().locator('[data-testid="level-badge"]').first();
	}

	heading()
	{
		return this.detailPanel().locator('[data-testid="heading"]').first();
	}

	metaUser()
	{
		return this.detailPanel().locator('[data-testid="meta-user"]').first();
	}

	countPill()
	{
		return this.detailPanel().locator('[data-testid="count-pill"]').first();
	}

	chainButton()
	{
		return this.detailPanel().locator('[data-testid="action-open-chain"]').first();
	}

	showWholeActionButton()
	{
		return this.detailPanel().locator('[data-testid="action-show-whole-action"]').first();
	}

	metaAction()
	{
		return this.detailPanel().locator('[data-testid="meta-action"]').first();
	}

	metaCorrelationChain()
	{
		return this.detailPanel().locator('[data-testid="meta-correlation-chain"]').first();
	}

	timelineActionNote()
	{
		return this.detailPanel().locator('[data-testid="timeline-action-note"]').first();
	}

	async openDrawerTab(label)
	{
		await this.detailPanel().getByRole('tab', {name: label}).first().click();
		await this.page.waitForTimeout(1000);
	}

	messageCode()
	{
		return this.detailPanel().locator('[data-testid="message-code"]').first();
	}

	stackCode()
	{
		return this.detailPanel().locator('[data-testid="stack-code"]').first();
	}

	limitBars()
	{
		return this.detailPanel().locator('[data-testid="limit-bar"]');
	}

	timelineNote()
	{
		return this.detailPanel().locator('[data-testid="timeline-note"]').first();
	}

	timelineGroups()
	{
		return this.detailPanel().locator('[data-testid="timeline-groups"]').first();
	}

	timelineEntries()
	{
		return this.detailPanel().locator('[data-testid="timeline-entry"]');
	}

	/**
	 * @description One of the drawer's copy affordances, by its own test id, so a check can read the
	 *              name that button carries rather than a name shared by all of them.
	 *
	 * @param {string} testId The copy button's test id, e.g. `copy-message`.
	 * @return {import('@playwright/test').Locator} The copy button's Lightning host.
	 */
	copyButton(testId)
	{
		return this.detailPanel().locator(`[data-testid="${testId}"]`).first();
	}

	overviewStat()
	{
		return this.detailPanel().locator('[data-spec-id="timeline-overview-stat"]').first();
	}

	gapNotes()
	{
		return this.detailPanel().locator('[data-spec-id="timeline-gap-note"]');
	}

	transactionCrumbs()
	{
		return this.detailPanel().locator('[data-spec-id="transaction-crumb"]');
	}

	transactionChevrons()
	{
		return this.detailPanel().locator('[data-spec-id="transaction-chevron"]');
	}

	minimapWarnPins()
	{
		return this.detailPanel().locator('[data-spec-id="minimap-warn-pin"]');
	}

	overviewStatCounts()
	{
		return this.overviewStat().locator('.stat__counts').first();
	}

	overviewStatDuration()
	{
		return this.overviewStat().locator('.stat__duration').first();
	}

	overviewStatClock()
	{
		return this.overviewStat().locator('.stat__icon').first();
	}

	overviewStatError()
	{
		return this.overviewStat().locator('.stat__error');
	}

	/**
	 * @description The separator and the error text of the overview line read as one part, where the
	 *              console groups them into an element of their own. Empty on a console that has not
	 *              taken that grouping yet, which is what lets a check fall back to the error text.
	 *
	 * @return {import('@playwright/test').Locator} The error clause, or nothing.
	 */
	overviewStatErrorClause()
	{
		return this.overviewStat().locator('.stat__errorclause');
	}

	timelineMinimap()
	{
		return this.detailPanel().locator('[data-spec-id="timeline-minimap"]').first();
	}

	minimapSegments()
	{
		return this.detailPanel().locator('[data-spec-id="minimap-segment"]');
	}

	transactionHeads()
	{
		return this.detailPanel().locator('[data-spec-id="transaction-head"]');
	}

	/**
	 * @description The warning pin hanging on one minimap segment, so a check can read a pin against
	 *              the segment it belongs to rather than against the minimap as a whole.
	 *
	 * @param {import('@playwright/test').Locator} segment One minimap segment.
	 * @return {import('@playwright/test').Locator} That segment's warning pin, empty when it carries none.
	 */
	segmentWarnPin(segment)
	{
		return segment.locator('[data-spec-id="minimap-warn-pin"]');
	}

	/**
	 * @description How far into the run one transaction began, as its head shows it.
	 *
	 * @param {import('@playwright/test').Locator} head One transaction head.
	 * @return {import('@playwright/test').Locator} That head's offset text.
	 */
	transactionOffset(head)
	{
		return head.locator('.toff').first();
	}

	/**
	 * @description How long one transaction took, as its head shows it beside the offset.
	 *
	 * @param {import('@playwright/test').Locator} head One transaction head.
	 * @return {import('@playwright/test').Locator} That head's duration text.
	 */
	transactionDuration(head)
	{
		return head.locator('.tdur').first();
	}

	/**
	 * @description The hand-off crumb of one transaction head, which says which transaction handed this
	 *              one its work.
	 *
	 * @param {import('@playwright/test').Locator} head One transaction head.
	 * @return {import('@playwright/test').Locator} That head's crumb, empty when the head carries none.
	 */
	transactionCrumb(head)
	{
		return head.locator('[data-spec-id="transaction-crumb"]');
	}

	/**
	 * @description The drawn icon inside one chevron wrapper. The wrapper reserves the width; the icon
	 *              is the shape that has to fit inside it, and only the rendered graphic carries a box
	 *              a browser will measure.
	 *
	 * @param {import('@playwright/test').Locator} chevron One chevron wrapper.
	 * @return {import('@playwright/test').Locator} The icon drawn inside it.
	 */
	chevronIcon(chevron)
	{
		return chevron.locator('svg').first();
	}
}

module.exports = LogConsolePage;
