// SPDX-License-Identifier: BUSL-1.1
const {expect} = require('@playwright/test');
const {clickNavTab} = require('../helpers/sf-navigation');
const {waitForSpinnerGone} = require('../helpers/wait-helpers');
const {ELEMENT_WAIT_MILLISECONDS} = require('../helpers/wait-times');

class ApiTestHarnessPage
{
	constructor(page)
	{
		this.page = page;
	}

	async navigate()
	{
		await clickNavTab(this.page, 'API Test Harness');
		await this.waitForReady();
	}

	async waitForReady()
	{
		await this.form().waitFor({state: 'visible', timeout: ELEMENT_WAIT_MILLISECONDS});
		await waitForSpinnerGone(this.page);
	}

	form()
	{
		// Prefer the explicit data-testid on the form's outer wrapper — stable across
		// dev/subscriber and independent of the kern-* vs c-* LWC tag-naming rule.
		return this.page.locator('[data-testid="api-test-harness-root"]').first();
	}

	async selectDirection(direction)
	{
		const group = this.form().locator('[data-testid="harness-direction"]');
		const target = group.getByText(direction, {exact: true});
		await target.click();
		// The direction-change async loadServices() race is covered by the
		// option-visible wait in selectService — don't double-wait here.
		const service = this.form().locator('[data-testid="harness-service"]');
		await service.waitFor({state: 'visible', timeout: 10_000});
	}

	async selectService(serviceLabel)
	{
		const combobox = this.form().locator('[data-testid="harness-service"]');
		await combobox.locator('input, button').first().click();
		const option = this.page.getByRole('option', {name: serviceLabel}).first();
		await option.waitFor({state: 'visible', timeout: 10_000});
		await option.click();
		await combobox.locator(`input[value*="${serviceLabel.replace(/"/g, '\\"')}"], [title="${serviceLabel}"]`).first()
		.waitFor({state: 'attached', timeout: 5_000}).catch(() =>
		{
		});
	}

	async setRecordId(recordId)
	{
		await this.form().locator('[data-id="recordId"] input').fill(recordId);
	}

	/**
	 * The visible Record ID label — "Record ID" when the selected service declares
	 * it needs a triggering record, "Record ID (optional)" when it does not.
	 */
	async recordIdLabel()
	{
		return this.form().locator('[data-id="recordId"] label').first().innerText();
	}

	async setBody(body)
	{
		await this.form().locator('[data-id="jsonBody"] textarea').fill(body);
	}

	parameterRow(index)
	{
		return this.form().locator('.parameter-row').nth(index);
	}

	async parameterRowCount()
	{
		return this.form().locator('.parameter-row').count();
	}

	/**
	 * Keys of the rows the harness seeded from the service's declared required inputs.
	 * A seeded row carries the "Required" marker in its tail column instead of the
	 * remove button, so filter on that marker rather than walking back up from it.
	 */
	async requiredParameterKeys()
	{
		const rows = this.form().locator('.parameter-row').filter({has: this.page.locator('[data-testid="required-marker"]')});
		const count = await rows.count();
		const keys = [];
		for(let index = 0; index < count; index++)
		{
			keys.push(await rows.nth(index).locator('[data-testid="parameter-key"] input').inputValue());
		}
		return keys;
	}

	/**
	 * Pass key as null to leave the key untouched — a seeded required row renders its
	 * key input read-only, so filling it would fail the actionability check.
	 */
	async setParameter(index, key, value)
	{
		const row = this.parameterRow(index);
		if(key !== null)
		{
			await row.locator('[data-testid="parameter-key"] input').fill(key);
		}
		await row.locator('[data-testid="parameter-value"] input').fill(value);
	}

	async addParameterRow()
	{
		const rows = this.form().locator('.parameter-row');
		const before = await rows.count();
		await this.form().locator('[data-testid="add-parameter"]').click();
		await expect(rows).toHaveCount(before + 1, {timeout: 5_000});
	}

	async removeParameterRow(index)
	{
		const rows = this.form().locator('.parameter-row');
		const before = await rows.count();
		await this.parameterRow(index).locator('[data-testid="remove-parameter"]').click();
		await expect(rows).toHaveCount(before - 1, {timeout: 5_000});
	}

	async setSafeMode(enabled)
	{
		await this.setToggle('safeMode', enabled);
	}

	async setMocking(enabled)
	{
		await this.setToggle('mocking', enabled);
	}

	/**
	 * lightning-input type="toggle" renders the checkbox input as visually
	 * hidden under a styled faux-switch. A direct .click() fails Playwright's
	 * actionability check ("element is not visible"), so use force:true —
	 * the same pattern scheduled-jobs.page.js uses for the is-active toggle.
	 */
	async setToggle(dataId, enabled)
	{
		const toggle = this.form().locator(`[data-id="${dataId}"] input[type="checkbox"]`);
		await toggle.waitFor({state: 'attached', timeout: 10_000});
		const current = await toggle.isChecked();
		if(current !== enabled)
		{
			await toggle.click({force: true});
			await expect.poll(() => toggle.isChecked(), {timeout: 5_000}).toBe(enabled);
		}
	}

	async getModeBadgeLabel()
	{
		return this.form().locator('[data-testid="mode-badge"]').textContent();
	}

	/**
	 * Reads the disabled state off the native button inside lightning-button's shadow
	 * root: the disabled flag lands there, not on the custom element Playwright's
	 * isEnabled() would otherwise inspect (it reports any custom element as enabled).
	 */
	async isExecuteEnabled()
	{
		return this.form().locator('[data-testid="harness-execute"] button').isEnabled();
	}

	async execute()
	{
		const executeBtn = this.form().locator('[data-testid="harness-execute"]');
		await executeBtn.evaluate(el => el.click());
		await waitForSpinnerGone(this.page, 30_000);
	}

	async reset()
	{
		await this.form().locator('[data-testid="harness-reset"]').click();
		await this.form().locator('[data-testid="empty-response"]').waitFor({state: 'visible', timeout: 5_000}).catch(() =>
		{
		});
	}

	async getStatusBadge()
	{
		return this.form().locator('[data-id="statusBadge"]').textContent();
	}

	async isResultVisible()
	{
		return this.form().locator('[data-id="statusBadge"]').isVisible();
	}

	async isEmptyResponseVisible()
	{
		return this.form().locator('[data-testid="empty-response"]').isVisible();
	}

	async getResultTabs()
	{
		return this.form().locator('lightning-tabset lightning-tab').allTextContents();
	}
}

module.exports = ApiTestHarnessPage;
