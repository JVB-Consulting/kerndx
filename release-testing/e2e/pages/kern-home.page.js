// SPDX-License-Identifier: Apache-2.0
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {ELEMENT_WAIT_MILLISECONDS} = require('../helpers/wait-times');

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

	async getHealthCheckActionItems()
	{
		const healthCheck = this.healthCheck();
		await healthCheck.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
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

	/**
	 * @description Locator for a passing health-check chip with the given check name. A passing check
	 * renders as a chip (not an action item), so this is the Pass-state signal for a specific check.
	 *
	 * @param {string} checkName The health-check display name.
	 *
	 * @return {import('@playwright/test').Locator} The passing chip locator, scoped to the health check.
	 */
	healthCheckPassingChip(checkName)
	{
		return this.healthCheck().locator('[data-testid="health-check-passing-chip"]', {hasText: checkName}).first();
	}

	/**
	 * @description Reads the rendered posture of a single health check: `warn` when it surfaces an action
	 * button, `pass` when it renders as a passing chip, or `pending` when neither has rendered yet (the
	 * result is still loading).
	 *
	 * @param {string} checkName The health-check display name.
	 *
	 * @return {Promise<'warn'|'pass'|'pending'>} The current rendered posture.
	 */
	async readHealthCheckPosture(checkName)
	{
		if(await this.healthCheckActionButton(checkName).isVisible().catch(() => false))
		{
			return 'warn';
		}
		if(await this.healthCheckPassingChip(checkName).isVisible().catch(() => false))
		{
			return 'pass';
		}
		return 'pending';
	}

	/**
	 * @description Re-runs the health check until the named check reaches the expected posture, absorbing
	 * the brief propagation delay between a custom-metadata deploy and the recomputed result. Throws when
	 * it never settles so a genuine non-recompute fails loudly rather than hanging on a stale render.
	 *
	 * @param {string} checkName The health-check display name.
	 * @param {'warn'|'pass'} expected The posture to wait for.
	 * @param {number} attempts Maximum number of refresh attempts.
	 *
	 * @return {Promise<void>}
	 */
	async refreshUntilHealthCheckPosture(checkName, expected, attempts = 6)
	{
		for(let attempt = 0; attempt < attempts; attempt++)
		{
			await this.refreshHealthCheck();
			if(await this.readHealthCheckPosture(checkName) === expected)
			{
				return;
			}
			await this.page.waitForTimeout(2_000);
		}
		throw new Error(`Health check "${checkName}" did not reach posture "${expected}" after ${attempts} refreshes`);
	}

	async clickHealthCheckActionNewTab(checkName)
	{
		const healthCheck = this.healthCheck();
		await healthCheck.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		const button = this.healthCheckActionButton(checkName);
		await button.waitFor({state: 'visible', timeout: 10_000});

		const popupPromise = this.page.context().waitForEvent('page', {timeout: ELEMENT_WAIT_MILLISECONDS});
		await button.click();
		const popup = await popupPromise;
		await popup.waitForLoadState('domcontentloaded').catch(() =>
		{
		});
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
		await this.applyRetentionModal().waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
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
		await modal.waitFor({state: 'hidden', timeout: ELEMENT_WAIT_MILLISECONDS}).catch(() =>
		{
		});
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
	 * @description Locator for the "Schedule Chain Watchdog" button on the Chain Watchdog health check row.
	 *
	 * @return {import('@playwright/test').Locator} Schedule button locator scoped to the health check component.
	 */
	scheduleWatchdogButton()
	{
		return this.healthCheck().locator('[data-testid="schedule-watchdog-button"]').first();
	}

	/**
	 * @description Locator for the "Customize schedule" link on the Chain Watchdog health check row.
	 *
	 * @return {import('@playwright/test').Locator} Customize link locator scoped to the health check component.
	 */
	customizeWatchdogLink()
	{
		return this.healthCheck().locator('[data-testid="customize-watchdog-link"]').first();
	}

	/**
	 * @description Locator for the "Schedule Chain Watchdog" confirmation dialogue rendered by the health
	 * check. Filtered by heading text because its footer button test ids (create-button, cancel-button)
	 * are shared with the scheduled-job editor modal.
	 *
	 * @return {import('@playwright/test').Locator} Modal dialog locator filtered by its heading text.
	 */
	watchdogConfirmModal()
	{
		return this.page.locator('section[role="dialog"]').filter({hasText: 'Schedule Chain Watchdog'}).first();
	}

	/**
	 * @description Locator for the watchdog confirmation dialogue's body root element.
	 *
	 * @return {import('@playwright/test').Locator} Body root locator scoped to the confirmation dialogue.
	 */
	watchdogConfirmRoot()
	{
		return this.watchdogConfirmModal().locator('[data-testid="schedule-watchdog-root"]').first();
	}

	/**
	 * @description Locator for the schedule picklist inside the watchdog confirmation dialogue.
	 *
	 * @return {import('@playwright/test').Locator} Schedule combobox locator scoped to the confirmation dialogue.
	 */
	watchdogConfirmSchedule()
	{
		return this.watchdogConfirmModal().locator('[data-testid="watchdog-confirm-schedule"]').first();
	}

	/**
	 * @description Locator for the Create button in the watchdog confirmation dialogue footer.
	 *
	 * @return {import('@playwright/test').Locator} Create button locator scoped to the confirmation dialogue.
	 */
	watchdogCreateButton()
	{
		return this.watchdogConfirmModal().locator('[data-testid="create-button"]').first();
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

	/**
	 * @description The job runner card Health Check renders beneath the readiness banner in both banner states.
	 *
	 * @return {import('@playwright/test').Locator} The card root.
	 */
	jobRunnerCard()
	{
		return this.kernHomeRoot().locator('[data-testid="job-runner-card"]').first();
	}

	jobRunnerActivateButton()
	{
		return this.jobRunnerCard().locator('[data-testid="job-runner-activate"]').first();
	}

	jobRunnerRepairButton()
	{
		return this.jobRunnerCard().locator('[data-testid="job-runner-repair"]').first();
	}

	jobRunnerDeactivateButton()
	{
		return this.jobRunnerCard().locator('[data-testid="job-runner-deactivate"]').first();
	}

	jobRunnerSummary()
	{
		return this.jobRunnerCard().locator('[data-testid="job-runner-summary"]').first();
	}

	jobRunnerActivator()
	{
		return this.jobRunnerCard().locator('[data-testid="job-runner-activator"]').first();
	}

	jobRunnerSlots()
	{
		return this.jobRunnerCard().locator('[data-testid="job-runner-slots"]').first();
	}

	jobRunnerModalRoot()
	{
		return this.page.locator('[data-testid="activate-job-runner-root"]').first();
	}

	/**
	 * @description Picks a check interval in the Activate dialogue's combobox by its minute value (60, 30, 15, 10 or 5).
	 *
	 * @param {string} minutes The check interval in minutes, as the option value.
	 *
	 * @return {Promise<void>}
	 */
	async chooseJobRunnerCheckInterval(minutes)
	{
		const combobox = this.jobRunnerModalRoot().locator('[data-testid="activate-job-runner-check-interval"]');
		await combobox.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		await combobox.locator('button[role="combobox"], button, input').first().click();
		// Option labels come from HealthCheck_JobRunner_CheckFrequencyOptions: "Every hour (1 slot)", "Every 15 minutes (4 slots)" and so on.
		const optionLabel = minutes === '60' ? /^Every hour/ : new RegExp(`^Every ${minutes} minutes`);
		const option = this.page.getByRole('option', {name: optionLabel}).first();
		await option.waitFor({state: 'visible', timeout: 10_000});
		await option.click();
	}

	async confirmJobRunnerModal()
	{
		// The confirm button sits in the modal's footer, outside the body's root, so it is found on the page.
		const confirm = this.page.locator('[data-testid="activate-job-runner-confirm"]').first();
		await confirm.evaluate((el) => el.click());
		await this.jobRunnerModalRoot().waitFor({state: 'hidden', timeout: ELEMENT_WAIT_MILLISECONDS});
		await waitForSpinnerGone(this.page);
	}

	/**
	 * @description Accepts the Deactivate confirmation (a lightning/confirm dialogue whose accept button reads OK).
	 *
	 * @return {Promise<void>}
	 */
	async confirmDeactivate()
	{
		const okButton = this.page.getByRole('button', {name: 'OK'}).first();
		await okButton.waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		await okButton.click();
		await waitForSpinnerGone(this.page);
	}
}

module.exports = KernHomePage;
