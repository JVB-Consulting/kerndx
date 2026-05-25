// SPDX-License-Identifier: BUSL-1.1
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');

class KernHomePage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await clickNavTab(this.page, 'Kern Home');
		await waitForSpinnerGone(this.page);
	}

	async getNavTabs()
	{
		const tabs = this.page.locator('one-app-nav-bar-item-root a');
		return tabs.allTextContents();
	}

	kernHomeRoot()
	{
		// Prefer the explicit data-testid on the outer wrapper — stable across dev/subscriber
		// and independent of the kern-* vs c-* LWC tag-naming rule.
		return this.page.locator('[data-testid="kern-home-root"]').first();
	}

	healthCheck()
	{
		// Inside kernHome, healthCheck renders as `c-health-check` (child LWC tag),
		// not `kern-health-check` (which only applies when it's a top-level FlexiPage LWC).
		return this.kernHomeRoot().locator('c-health-check').first();
	}

	toolCard(key)
	{
		return this.kernHomeRoot().locator(`.tool-card-wrapper:has(lightning-button[data-key="${key}"])`).first();
	}

	toolLaunchButton(key)
	{
		return this.kernHomeRoot().locator(`lightning-button[data-key="${key}"]`).first();
	}

	async getToolCardTitles()
	{
		const root = this.kernHomeRoot();
		const cards = root.locator('.tool-card lightning-card .slds-card__header-title, .tool-card lightning-card .slds-truncate');
		const titles = [];
		const count = await cards.count();
		for(let i = 0; i < count; i++)
		{
			const title = await cards.nth(i).textContent().catch(() => '');
			if(title?.trim())
			{
				titles.push(title.trim());
			}
		}
		return titles;
	}

	async allHealthChecksPassing()
	{
		const healthCheck = this.healthCheck();
		await healthCheck.waitFor({state: 'visible', timeout: 15_000});
		await waitForSpinnerGone(this.page);

		const allPassBanner = healthCheck.locator('[data-testid="health-check-all-pass"]');
		return allPassBanner.isVisible();
	}

	async getHealthCheckActionItems()
	{
		const healthCheck = this.healthCheck();
		await healthCheck.waitFor({state: 'visible', timeout: 15_000});
		await waitForSpinnerGone(this.page);

		const items = healthCheck.locator('[data-testid="health-check-item"]');
		const count = await items.count();
		const results = [];

		for(let i = 0; i < count; i++)
		{
			const item = items.nth(i);
			const name = await item.locator('[data-testid="health-check-name"]').textContent();
			const detail = await item.locator('[data-testid="health-check-detail"]').textContent();
			const icon = item.locator('lightning-icon').first();
			const iconName = await icon.getAttribute('icon-name').catch(() => '');
			results.push({
				name: name?.trim(), detail: detail?.trim(), iconName, isPass: iconName?.includes('success')
			});
		}
		return results;
	}

	async refreshHealthCheck()
	{
		const healthCheck = this.healthCheck();
		await healthCheck.locator('[data-testid="health-check-refresh"]').first().click();
		await waitForSpinnerGone(this.page);
	}

	async launchTool(key)
	{
		await this.toolLaunchButton(key).click();
		await waitForSpinnerGone(this.page);
	}

	healthCheckActionButton(checkName)
	{
		return this.healthCheck().locator(`lightning-button[data-name="${checkName}"]`).first();
	}

	async clickHealthCheckActionNewTab(checkName)
	{
		const healthCheck = this.healthCheck();
		await healthCheck.waitFor({state: 'visible', timeout: 15_000});
		const button = this.healthCheckActionButton(checkName);
		await button.waitFor({state: 'visible', timeout: 10_000});

		const popupPromise = this.page.context().waitForEvent('page', {timeout: 15_000});
		await button.click();
		const popup = await popupPromise;
		await popup.waitForLoadState('domcontentloaded').catch(() => {});
		return popup;
	}

	/**
	 * @description Locator for the "Apply Recommended Retention" button on the Data Retention health check card.
	 *
	 * @return {import('@playwright/test').Locator} Apply button locator scoped to the health check component.
	 */
	applyRetentionButton()
	{
		return this.healthCheck().locator('[data-testid="apply-retention-button"]').first();
	}

	/**
	 * @description Locator for the "Customize each job" link on the Data Retention health check card.
	 *
	 * @return {import('@playwright/test').Locator} Customize link locator scoped to the health check component.
	 */
	customizeRetentionLink()
	{
		return this.healthCheck().locator('[data-testid="customize-retention-link"]').first();
	}

	/**
	 * @description Locator for the "Apply Recommended Retention" confirmation modal rendered by the health check.
	 *
	 * @return {import('@playwright/test').Locator} Modal dialog locator filtered by its heading text.
	 */
	applyRetentionModal()
	{
		return this.page.locator('section[role="dialog"]').filter({hasText: 'Apply Recommended Retention'}).first();
	}

	/**
	 * @description Locator for all retention sub-rows rendered while the health check is in customize mode.
	 *
	 * @return {import('@playwright/test').Locator} Collection locator for every retention sub-row element.
	 */
	retentionSubRows()
	{
		return this.healthCheck().locator('[data-testid="retention-sub-row"]');
	}

	/**
	 * @description Locator for the "Set up" button inside a specific retention sub-row, keyed by object API name.
	 *
	 * @param {string} objectApiName The namespaced object API name (e.g. `kern__LogEntry__c`).
	 *
	 * @return {import('@playwright/test').Locator} Set-up button locator for the matching sub-row.
	 */
	setUpButton(objectApiName)
	{
		return this.healthCheck().locator(`[data-testid="set-up-button"][data-object-api-name="${objectApiName}"]`).first();
	}

	/**
	 * @description Clicks the "Apply Recommended Retention" button and waits for the confirmation modal to appear.
	 *
	 * @return {Promise<void>} Resolves once the modal is visible.
	 */
	async clickApplyRetention()
	{
		await this.applyRetentionButton().click();
		await this.applyRetentionModal().waitFor({state: 'visible', timeout: 15_000});
	}

	/**
	 * @description Confirms the apply-retention modal and waits for the spinner to settle after job creation.
	 *
	 * @return {Promise<void>} Resolves once the modal action completes and the UI is idle.
	 */
	async confirmApplyRetention()
	{
		const modal = this.applyRetentionModal();
		await modal.locator('[data-testid="confirm-button"]').click();
		await modal.waitFor({state: 'hidden', timeout: 15_000}).catch(() => {});
		await waitForSpinnerGone(this.page);
	}

	/**
	 * @description Clicks the "Customize each job" link and waits for the first retention sub-row to render.
	 *
	 * @return {Promise<void>} Resolves once the sub-row list is visible.
	 */
	async clickCustomizeRetention()
	{
		await this.customizeRetentionLink().click();
		await this.retentionSubRows().first().waitFor({state: 'visible', timeout: 10_000});
	}

	/**
	 * @description Locator for the Action-required (fail) section wrapper in the health check card.
	 *
	 * @return {import('@playwright/test').Locator} Fail-section container locator.
	 */
	failSection()
	{
		return this.healthCheck().locator('[data-testid="fail-section"]').first();
	}

	/**
	 * @description Locator for the Review-recommended (warn) section wrapper in the health check card.
	 *
	 * @return {import('@playwright/test').Locator} Warn-section container locator.
	 */
	warnSection()
	{
		return this.healthCheck().locator('[data-testid="warn-section"]').first();
	}

	/**
	 * @description Locator for the "Data Retention — customizing N jobs" headline visible while in customize mode.
	 *
	 * @return {import('@playwright/test').Locator} Headline element locator.
	 */
	customizeHeadline()
	{
		return this.healthCheck().locator('[data-testid="customize-headline"]').first();
	}

	/**
	 * @description Locator for the customize-mode help paragraph describing the Set up buttons.
	 *
	 * @return {import('@playwright/test').Locator} Help paragraph locator.
	 */
	customizeHelp()
	{
		return this.healthCheck().locator('[data-testid="customize-help"]').first();
	}

	/**
	 * @description Locator for the "Back to one-click apply" link rendered in customize-mode header.
	 *
	 * @return {import('@playwright/test').Locator} Back link locator.
	 */
	backToApplyLink()
	{
		return this.healthCheck().locator('[data-testid="back-to-apply-link"]').first();
	}

	/**
	 * @description Clicks the "Back to one-click apply" link and waits for the apply view to restore.
	 *
	 * @return {Promise<void>} Resolves once the apply button is visible again.
	 */
	async clickBackToApply()
	{
		await this.backToApplyLink().click();
		await this.applyRetentionButton().waitFor({state: 'visible', timeout: 10_000});
	}

	/**
	 * @description Reads the text of every retention sub-row meta label (record count + retention days).
	 *
	 * @return {Promise<string[]>} Resolves with an array of meta strings, one per sub-row.
	 */
	async getRetentionSubRowMetaTexts()
	{
		const metas = this.healthCheck().locator('[data-testid="retention-sub-row"] .retention-sub-row__meta');
		const count = await metas.count();
		const results = [];
		for(let i = 0; i < count; i++)
		{
			const text = await metas.nth(i).textContent();
			results.push((text || '').replace(/\s+/g, ' ').trim());
		}
		return results;
	}
}

module.exports = KernHomePage;
