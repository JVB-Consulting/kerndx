// SPDX-License-Identifier: BUSL-1.1
const {getInstanceUrl, ensureAuthenticated} = require('../helpers/sf-auth');
const {soqlQuery} = require('../helpers/sf-cli');
const {waitForPageLoad} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

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

	approximateBadge()
	{
		return this.root().locator('[data-testid="totals-approximate"]').first();
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
	 * @description Selects a row via its single-select radio (max-row-selection is 1), falling back
	 *              to a plain row click — the same tolerant pattern as the Chain Monitor page object.
	 */
	async selectRow(index)
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
		await this.page.waitForTimeout(2000);
		await waitForSpinnerGone(this.page);
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
	 * @description Drives the datatable's endless scroll by scrolling its internal scroll container
	 *              to the bottom, which fires the loadmore event that appends the next page.
	 */
	async scrollTableToBottom()
	{
		const scroller = this.table().locator('.slds-scrollable_y').first();
		await scroller.evaluate((element) =>
		{
			element.scrollTop = element.scrollHeight;
		});
		await this.page.waitForTimeout(2500);
		await waitForSpinnerGone(this.page);
	}

	emptyState()
	{
		return this.root().locator('[data-testid="empty-state"]').first();
	}

	// ── detail drawer ─────────────────────────────────────────────────────

	detailPanel()
	{
		return this.root().locator('[data-testid="detail-panel"]').first();
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
}

module.exports = LogConsolePage;
