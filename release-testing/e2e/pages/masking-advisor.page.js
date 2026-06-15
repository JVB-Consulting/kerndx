// SPDX-License-Identifier: BUSL-1.1
const {getInstanceUrl, ensureAuthenticated} = require('../helpers/sf-auth');
const {soqlQuery} = require('../helpers/sf-cli');
const {waitForPageLoad} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

// Resolved once per process: 'kern__' on a subscriber org, '' on the no-namespace unmanaged org.
// The Data Masking Advisor is not a nav tab in the Kern app, so it is reached by tab URL
// (`/lightning/n/<ns>DataMaskingAdvisor`); every other selector is data-testid only and therefore
// namespace-stable, so the spec runs unchanged against both the unmanaged org and a subscriber install.
let cachedNamespacePrefix;

// The advisor's modals (rule-detail, export, add-rule) render as real `lightning-modal`
// dialogs at the document root — NOT inside the advisor's shadow root — so their locators are
// scoped to the page, not to the advisor card.
const MODAL_ROOT = 'lightning-modal, [role="dialog"]';

class MaskingAdvisorPage
{
	constructor(page)
	{
		this.page = page;
	}

	/**
	 * @description Resolves the org's namespace prefix for the advisor tab API name by reading the
	 *              CTRL_MaskingAdvisor class's NamespacePrefix via the Tooling API. Returns `kern__`
	 *              on a subscriber org and an empty string on the no-namespace unmanaged org. Cached for
	 *              the process so the lookup runs at most once per test run.
	 *
	 * @return {string} The namespace prefix including the trailing `__`, or `''` when unmanaged.
	 */
	namespacePrefix()
	{
		if(cachedNamespacePrefix === undefined)
		{
			const rows = soqlQuery('SELECT NamespacePrefix FROM ApexClass WHERE Name = \'CTRL_MaskingAdvisor\' LIMIT 1', {tooling: true});
			const namespace = rows[0] && rows[0].NamespacePrefix;
			cachedNamespacePrefix = namespace ? `${namespace}__` : '';
		}
		return cachedNamespacePrefix;
	}

	/**
	 * @description Navigates to the Data Masking Advisor tab by URL (namespace-resolved) and waits for the
	 *              landing Add-object button plus the initial posture/inventory loads to settle.
	 *
	 * @return {Promise<void>} Resolves once the landing view is interactive.
	 */
	async navigate()
	{
		await ensureAuthenticated(this.page);
		const tabApiName = `${this.namespacePrefix()}DataMaskingAdvisor`;
		await this.page.goto(`${getInstanceUrl()}/lightning/n/${tabApiName}`, {waitUntil: 'domcontentloaded'});
		await waitForPageLoad(this.page);
		await this.addObjectButton().waitFor({state: 'visible', timeout: 60_000});
		await this.page.waitForTimeout(2000);
		await waitForSpinnerGone(this.page);
	}

	// ---- Landing -----------------------------------------------------------------------------------

	/**
	 * @description Locator for the scope banner that explains the two masking modes on the landing view.
	 *
	 * @return {import('@playwright/test').Locator} The scope-banner element locator.
	 */
	scopeBanner()
	{
		return this.page.locator('[data-testid="scope-banner"]').first();
	}

	/**
	 * @description Locator for the landing Add-object button that opens the grouped object dialog.
	 *
	 * @return {import('@playwright/test').Locator} The add-object-button element locator.
	 */
	addObjectButton()
	{
		return this.page.locator('[data-testid="add-object-button"]').first();
	}

	/**
	 * @description Locator for the posture tile count of objects carrying active masking.
	 *
	 * @return {import('@playwright/test').Locator} The objects-with-masking count locator.
	 */
	postureObjectsCount()
	{
		return this.page.locator('[data-testid="posture-objects-count"]').first();
	}

	/**
	 * @description Locator for the posture tile count of dead masking configurations.
	 *
	 * @return {import('@playwright/test').Locator} The dead-configuration count locator.
	 */
	postureDeadCount()
	{
		return this.page.locator('[data-testid="posture-dead-count"]').first();
	}

	/**
	 * @description Locator for the org-wide masked-object inventory section on the landing view.
	 *
	 * @return {import('@playwright/test').Locator} The inventory section locator.
	 */
	inventory()
	{
		return this.page.locator('[data-testid="inventory"]').first();
	}

	/**
	 * @description Collection locator for every masked-object inventory row.
	 *
	 * @return {import('@playwright/test').Locator} The inventory-row collection locator.
	 */
	inventoryRows()
	{
		return this.page.locator('[data-testid="inventory-row"]');
	}

	/**
	 * @description Reads the trimmed number rendered in a landing posture tile.
	 *
	 * @param {import('@playwright/test').Locator} locator The posture-count locator to read.
	 *
	 * @return {Promise<number>} The parsed integer, or NaN when the tile text is non-numeric.
	 */
	async readCount(locator)
	{
		const text = (await locator.textContent()) || '';
		return parseInt(text.trim(), 10);
	}

	/**
	 * @description Returns the `data-api-name` of every inventory row, in render order.
	 *
	 * @return {Promise<string[]>} The masked-object API names listed on the landing view.
	 */
	async inventoryApiNames()
	{
		const rows = this.inventoryRows();
		const count = await rows.count();
		const names = [];
		for(let i = 0; i < count; i++)
		{
			names.push(await rows.nth(i).getAttribute('data-api-name'));
		}
		return names;
	}

	/**
	 * @description Clicks an inventory row to drill into its per-object view and waits for the object-wide
	 *              banner (the per-object view's anchor) to render.
	 *
	 * @param {string} apiName The masked object's API name (matches the row's `data-api-name`).
	 *
	 * @return {Promise<void>} Resolves once the per-object view is visible.
	 */
	async drillIntoInventoryRow(apiName)
	{
		await this.page.locator(`[data-testid="inventory-row"][data-api-name="${apiName}"]`).first().click();
		await this.objectWideBanner().waitFor({state: 'visible', timeout: 30_000});
		await this.page.waitForTimeout(1500);
		await waitForSpinnerGone(this.page);
	}

	// ---- Add-object dialog ---------------------------------------------------------------------------

	/**
	 * @description Selects an object via the grouped Add-object dialog (opened from the landing button),
	 *              then waits for the per-object view (object-wide banner) to render. The dialog is a real
	 *              `lightning-modal` at the document root, so its locators are page-scoped.
	 *
	 * @param {string} apiName The object API name to select (e.g. `Account`); matches the option `data-api-name`.
	 *
	 * @return {Promise<void>} Resolves once the per-object view is visible.
	 */
	async selectObject(apiName)
	{
		await this.addObjectButton().click();
		const search = this.page.locator('[data-testid="add-object-search"] input');
		await search.waitFor({state: 'visible', timeout: 20_000});
		await search.fill(apiName);
		await this.page.waitForTimeout(800);
		await this.page.locator(`[data-testid="add-object-option"][data-api-name="${apiName}"]`).first().click({timeout: 20_000});
		await this.objectWideBanner().waitFor({state: 'visible', timeout: 30_000});
		await this.page.waitForTimeout(2000);
		await waitForSpinnerGone(this.page);
	}

	// ---- Layout / overflow -------------------------------------------------------------------------

	/**
	 * @description Measures horizontal overflow of the page and of the advisor card, mirroring the proven
	 *              scripted visual-pass logic. Used to assert no horizontal scroll at 1280×720.
	 *
	 * @return {Promise<{pageOverflow: number, innerWidth: number, cardOverflow: (number|string), cardRight: (number|null)}>}
	 *         The page scrollWidth−clientWidth, the viewport width, the advisor card overflow, and the card's right edge.
	 */
	async measureOverflow()
	{
		const pageMetrics = await this.page.evaluate(() =>
		{
			const scroller = document.scrollingElement || document.documentElement;
			return {scrollWidth: scroller.scrollWidth, clientWidth: scroller.clientWidth, innerWidth: window.innerWidth};
		});
		const card = this.page.locator('lightning-card').filter({has: this.page.locator('[data-testid="add-object-button"]')}).first();
		let cardOverflow = null;
		let cardRight = null;
		try
		{
			cardOverflow = await card.evaluate((element) => element.scrollWidth - element.clientWidth);
			const box = await card.boundingBox();
			cardRight = box ? Math.round(box.x + box.width) : null;
		}
		catch(error)
		{
			cardOverflow = 'n/a';
		}
		return {pageOverflow: pageMetrics.scrollWidth - pageMetrics.clientWidth, innerWidth: pageMetrics.innerWidth, cardOverflow, cardRight};
	}

	// ---- Sections ----------------------------------------------------------------------------------

	/**
	 * @description Locator for the Ready section (fields with a recommended rule).
	 *
	 * @return {import('@playwright/test').Locator} The Ready-section locator.
	 */
	sectionReady()
	{
		return this.page.locator('[data-testid="section-ready"]').first();
	}

	/**
	 * @description Locator for the Manual-review section (sensitive fields without a recommended rule).
	 *
	 * @return {import('@playwright/test').Locator} The Manual-review-section locator.
	 */
	sectionManualReview()
	{
		return this.page.locator('[data-testid="section-manual-review"]').first();
	}

	/**
	 * @description Locator for the Other section (remaining fields, including likely misses).
	 *
	 * @return {import('@playwright/test').Locator} The Other-section locator.
	 */
	sectionOther()
	{
		return this.page.locator('[data-testid="section-other"]').first();
	}

	/**
	 * @description Locator for a field row in any section, keyed by its field API name.
	 *
	 * @param {string} apiName The field API name (matches the row's `data-api-name`).
	 *
	 * @return {import('@playwright/test').Locator} The matching `<tr>` field-row locator.
	 */
	fieldRow(apiName)
	{
		return this.page.locator(
				`[data-api-name="${apiName}"][data-testid="field-row"], [data-api-name="${apiName}"][data-testid="manual-review-row"], [data-api-name="${apiName}"][data-testid="other-field-row"]`)
		.first();
	}

	// ---- Banners -----------------------------------------------------------------------------------

	/**
	 * @description Locator for the always-rendered object-wide coverage banner.
	 *
	 * @return {import('@playwright/test').Locator} The object-wide-banner locator.
	 */
	objectWideBanner()
	{
		return this.page.locator('[data-testid="object-wide-banner"]').first();
	}

	/**
	 * @description Locator for the object-wide banner's expand/collapse toggle (carries `aria-expanded`).
	 *
	 * @return {import('@playwright/test').Locator} The object-wide-banner toggle locator.
	 */
	objectWideBannerToggle()
	{
		return this.page.locator('[data-testid="object-wide-banner-toggle"]').first();
	}

	/**
	 * @description Locator for the configuration-health banner, present only when the object has inactive
	 *              object-wide rules or dead field targets.
	 *
	 * @return {import('@playwright/test').Locator} The health-banner locator.
	 */
	healthBanner()
	{
		return this.page.locator('[data-testid="health-banner"]').first();
	}

	/**
	 * @description Locator for the configuration-health banner's expand/collapse toggle (carries `aria-expanded`).
	 *
	 * @return {import('@playwright/test').Locator} The health-banner toggle locator.
	 */
	healthBannerToggle()
	{
		return this.page.locator('[data-testid="health-banner-toggle"]').first();
	}

	/**
	 * @description Locator for the Add object-wide rule button, revealed when the object-wide banner expands.
	 *
	 * @return {import('@playwright/test').Locator} The add-object-wide-rule button locator.
	 */
	addObjectWideRule()
	{
		return this.page.locator('[data-testid="add-object-wide-rule"]').first();
	}

	/**
	 * @description Toggles a banner section by clicking its toggle and returns the before/after
	 *              `aria-expanded` values so a test can assert the flip.
	 *
	 * @param {import('@playwright/test').Locator} toggle The banner-toggle locator to click.
	 *
	 * @return {Promise<{before: (string|null), after: (string|null)}>} The aria-expanded values around the click.
	 */
	async flipToggle(toggle)
	{
		const before = await toggle.getAttribute('aria-expanded');
		await toggle.scrollIntoViewIfNeeded();
		await toggle.click();
		await this.page.waitForTimeout(500);
		const after = await toggle.getAttribute('aria-expanded');
		return {before, after};
	}

	// ---- Chips -------------------------------------------------------------------------------------

	/**
	 * @description Locator for every field-level chip on a given field row (object-wide chips excluded).
	 *
	 * @param {string} apiName The field API name whose row's chips to return.
	 *
	 * @return {import('@playwright/test').Locator} A collection locator over the row's `field-chip` elements.
	 */
	fieldChipsOn(apiName)
	{
		return this.fieldRow(apiName).locator('[data-testid="field-chip"]');
	}

	/**
	 * @description Collects each field-level chip's identifying attributes (rule developer name, origin,
	 *              desired/ticked state) for a given field row.
	 *
	 * @param {string} apiName The field API name whose chips to read.
	 *
	 * @return {Promise<Array<{rule: string, origin: string, desired: string}>>} One descriptor per chip.
	 */
	async fieldChipDescriptors(apiName)
	{
		const chips = this.fieldChipsOn(apiName);
		const count = await chips.count();
		const descriptors = [];
		for(let i = 0; i < count; i++)
		{
			const chip = chips.nth(i);
			descriptors.push({
				rule: await chip.getAttribute('data-rule'), origin: await chip.getAttribute('data-origin'), desired: await chip.getAttribute('data-desired')
			});
		}
		return descriptors;
	}

	// ---- Rule-detail modal -------------------------------------------------------------------------

	/**
	 * @description Clicks the first visible chip-detail trigger on a field row to open the rule-detail
	 *              modal, then waits for the modal (a document-root lightning-modal) to render.
	 *
	 * @param {string} apiName The field API name whose first chip-detail to open.
	 *
	 * @return {Promise<import('@playwright/test').Locator>} The opened chip-detail trigger (for focus-return checks).
	 */
	async openRuleDetailFromField(apiName)
	{
		const trigger = this.fieldRow(apiName).locator('[data-testid="chip-detail"]').first();
		await trigger.scrollIntoViewIfNeeded();
		await trigger.click();
		await this.ruleDetailModal().waitFor({state: 'visible', timeout: 20_000});
		return trigger;
	}

	/**
	 * @description Locator for the rule-detail modal (the document-root dialog carrying its Done button).
	 *
	 * @return {import('@playwright/test').Locator} The rule-detail modal locator.
	 */
	ruleDetailModal()
	{
		return this.page.locator(`${MODAL_ROOT}`).filter({has: this.page.locator('[data-testid="done-button"]')}).first();
	}

	/**
	 * @description Locator for the rule-detail modal's test-input field.
	 *
	 * @return {import('@playwright/test').Locator} The test-input locator.
	 */
	ruleDetailTestInput()
	{
		return this.page.locator('[data-testid="test-input"]').first();
	}

	/**
	 * @description Locator for the rule-detail modal's preview ("test") button.
	 *
	 * @return {import('@playwright/test').Locator} The test-button locator.
	 */
	ruleDetailTestButton()
	{
		return this.page.locator('[data-testid="test-button"]').first();
	}

	/**
	 * @description Locator for the rule-detail modal's masked-output element (rendered when masking changes the value).
	 *
	 * @return {import('@playwright/test').Locator} The test-masked locator.
	 */
	ruleDetailTestMasked()
	{
		return this.page.locator('[data-testid="test-masked"]').first();
	}

	/**
	 * @description Locator for the rule-detail modal's masked-after-deploy toggle (shown for dormant candidate rules).
	 *
	 * @return {import('@playwright/test').Locator} The masked-after-deploy locator.
	 */
	ruleDetailMaskedAfterDeploy()
	{
		return this.page.locator('[data-testid="masked-after-deploy"]').first();
	}

	/**
	 * @description Locator for the rule-detail modal's Done (close) button.
	 *
	 * @return {import('@playwright/test').Locator} The done-button locator.
	 */
	ruleDetailDoneButton()
	{
		return this.page.locator('[data-testid="done-button"]').first();
	}

	/**
	 * @description Fills the rule-detail test input and runs the preview, returning the result text. Waits
	 *              for the preview to actually resolve — the masked element (when masking changes the value)
	 *              or the message element (a no-change / hint result) — then returns whichever rendered, so a
	 *              no-change rule yields a readable value rather than an opaque timeout.
	 *
	 * @param {string} sample The plain value to mask.
	 *
	 * @return {Promise<string>} The trimmed preview-result text (masked output, or the result message).
	 */
	async runRuleDetailPreview(sample)
	{
		const input = this.ruleDetailTestInput().locator('input, textarea').first();
		await input.fill(sample);
		await this.ruleDetailTestButton().click();
		const masked = this.ruleDetailTestMasked();
		const message = this.page.locator('[data-testid="test-message"]').first();
		await masked.or(message).waitFor({state: 'visible', timeout: 10_000});
		if(await masked.isVisible().catch(() => false))
		{
			return ((await masked.textContent()) || '').trim();
		}
		return ((await message.textContent()) || '').trim();
	}

	/**
	 * @description Reads the deep-focused active element's data-testid (piercing shadow roots) so a test can
	 *              assert focus returned to the trigger after a modal closes.
	 *
	 * @return {Promise<(string|null)>} The active element's data-testid, its tag name, or null.
	 */
	async deepActiveTestId()
	{
		return this.page.evaluate(() =>
		{
			function deepActive(root)
			{
				let active = root.activeElement;
				while(active && active.shadowRoot && active.shadowRoot.activeElement)
				{
					active = active.shadowRoot.activeElement;
				}
				return active;
			}

			const active = deepActive(document);
			return active ? ((active.getAttribute && active.getAttribute('data-testid')) || active.tagName) : null;
		});
	}

	// ---- Add-rule menus ----------------------------------------------------------------------------

	/**
	 * @description Clicks the per-field add-rule button to open the add-rule menu and waits for it to render.
	 *
	 * @param {string} apiName The field API name whose add-rule menu to open.
	 *
	 * @return {Promise<void>} Resolves once the menu (a document-root modal) is visible.
	 */
	async openAddRuleMenu(apiName)
	{
		const trigger = this.fieldRow(apiName).locator('[data-testid="add-rule"]').first();
		await trigger.scrollIntoViewIfNeeded();
		await trigger.click();
		await this.addRuleMenu().waitFor({state: 'visible', timeout: 20_000});
	}

	/**
	 * @description Locator for the add-rule menu (the document-root dialog carrying its intro/items/empty state).
	 *
	 * @return {import('@playwright/test').Locator} The add-rule menu locator.
	 */
	addRuleMenu()
	{
		return this.page.locator(`${MODAL_ROOT}`).filter({has: this.page.locator('[data-testid="menu-intro"], [data-testid="menu-item"], [data-testid="menu-empty"]')}).first();
	}

	/**
	 * @description Collection locator for every selectable rule item in the add-rule menu.
	 *
	 * @return {import('@playwright/test').Locator} The menu-item collection locator.
	 */
	addRuleMenuItems()
	{
		return this.page.locator('[data-testid="menu-item"]');
	}

	/**
	 * @description Locator for the add-rule menu's close button.
	 *
	 * @return {import('@playwright/test').Locator} The menu-close locator.
	 */
	addRuleMenuClose()
	{
		return this.page.locator('[data-testid="menu-close"]').first();
	}

	/**
	 * @description Locator for the add-rule menu's create-custom-rule escape hatch (deep-links to Setup).
	 *
	 * @return {import('@playwright/test').Locator} The create-custom-rule locator.
	 */
	createCustomRule()
	{
		return this.page.locator('[data-testid="create-custom-rule"]').first();
	}

	// ---- Summary / export --------------------------------------------------------------------------

	/**
	 * @description Locator for the summary-strip stat reporting the count of queued changes.
	 *
	 * @return {import('@playwright/test').Locator} The summary-changes locator.
	 */
	summaryChanges()
	{
		return this.page.locator('[data-testid="summary-changes"]').first();
	}

	/**
	 * @description Locator for the Export package button (disabled until the draft has a queued change).
	 *
	 * @return {import('@playwright/test').Locator} The export-package-button locator.
	 */
	exportButton()
	{
		return this.page.locator('[data-testid="export-package-button"]').first();
	}

	/**
	 * @description Whether the export button is enabled (i.e. the draft has at least one queued change).
	 *
	 * @return {Promise<boolean>} True when the export button is interactable.
	 */
	async isExportEnabled()
	{
		return this.exportButton().isEnabled();
	}

	/**
	 * @description Opens the export modal by clicking the export button and waits for the export modal
	 *              (a document-root lightning-modal carrying the deploy command) to render.
	 *
	 * @return {Promise<void>} Resolves once the export modal is visible.
	 */
	async openExport()
	{
		await this.exportButton().scrollIntoViewIfNeeded();
		await this.exportButton().click();
		await this.exportModal().waitFor({state: 'visible', timeout: 20_000});
	}

	/**
	 * @description Locator for the export modal (the document-root dialog carrying the deploy command).
	 *
	 * @return {import('@playwright/test').Locator} The export modal locator.
	 */
	exportModal()
	{
		return this.page.locator(`${MODAL_ROOT}`).filter({has: this.page.locator('[data-testid="deploy-command"]')}).first();
	}

	/**
	 * @description Locator for the export modal's change-summary line.
	 *
	 * @return {import('@playwright/test').Locator} The change-summary locator.
	 */
	changeSummary()
	{
		return this.page.locator('[data-testid="change-summary"]').first();
	}

	/**
	 * @description Collection locator for every change row in the export package list.
	 *
	 * @return {import('@playwright/test').Locator} The package-row collection locator.
	 */
	packageRows()
	{
		return this.page.locator('[data-testid="package-row"]');
	}

	/**
	 * @description Locator for the export modal's org-alias input field.
	 *
	 * @return {import('@playwright/test').Locator} The alias-input inner input locator.
	 */
	aliasInput()
	{
		return this.page.locator('[data-testid="alias-input"]').locator('input').first();
	}

	/**
	 * @description Locator for the export modal's generated deploy-command block.
	 *
	 * @return {import('@playwright/test').Locator} The deploy-command locator.
	 */
	deployCommand()
	{
		return this.page.locator('[data-testid="deploy-command"]').first();
	}

	/**
	 * @description Locator for the export modal's Download button (fires the package zip).
	 *
	 * @return {import('@playwright/test').Locator} The download-button locator.
	 */
	downloadButton()
	{
		return this.page.locator('[data-testid="download-button"]').first();
	}

	/**
	 * @description Collects each export package-row's verb and main text, so a test can assert the rows
	 *              are grouped by verb (add / disable / re-enable) and find specific rule rows.
	 *
	 * @return {Promise<Array<{verb: string, text: string}>>} One descriptor per package row.
	 */
	async packageRowDescriptors()
	{
		const rows = this.packageRows();
		const count = await rows.count();
		const descriptors = [];
		for(let i = 0; i < count; i++)
		{
			const row = rows.nth(i);
			descriptors.push({
				verb: await row.getAttribute('data-verb'), text: ((await row.textContent()) || '').replace(/\s+/g, ' ').trim()
			});
		}
		return descriptors;
	}
}

module.exports = MaskingAdvisorPage;
